# encoding: utf-8

require_relative 'config'
require 'base64'
require 'logger'

class String
  def daisuki separator=' '
    "わぁい#{self}#{separator}あかり#{self}大好き"
  end

  def indices c
    (0 ... self.length).find_all { |i| self[i,1] == c }
  end

  def cjk?
    !!(self =~ /\p{Han}|\p{Katakana}|\p{Hiragana}|\p{Hangul}/)
  end
end

module Akari
  @c = Configuration.for 'akari'

  module_function
  def config namespace=''
    namespace.empty? ? @c : @c.send(namespace)
  end

  def logger
    @logger ||= Logger.new @c.log.path, @c.log.num_files, @c.log.max_size
  end

  def fetch
    words, url = loop do
      words = loop do
        words = Akari::Tweets.get_words
        break words unless words.strip.empty?
      end

      url = Akari::Search::search words
      break words, url unless url.nil?
    end

    path = "#{@c.queue_path}/#{Base64.urlsafe_encode64 words}.#{@c.extension}"
    image = Akari::Image::akarify words, url
    image.write path
    image.destroy! # Release memory
    path
  end

  def image_paths
    Dir["#{@c.queue_path}/*.#{@c.extension}"]
  end

  def enqueue
    fetch until image_paths.length >= @c.queue_size
  end

  def dequeue
    path = image_paths.min_by { |f| File.mtime f }
    return if path.nil?

    Tweets::tweet_image path
    File.delete path
  end

  module Tweets
    require 'twitter'
    @c = Akari::config 'twitter'

    module_function
    def client
      @client ||= Twitter::REST::Client.new do |config|
        config.consumer_key        = @c.consumer_key
        config.consumer_secret     = @c.consumer_secret
        config.access_token        = @c.access_token
        config.access_token_secret = @c.access_token_secret
      end
    end

    def get_words
      @tweets ||= client
        .home_timeline(count: 200)
        .reject { |tweet| tweet.user.screen_name == @c.screen_name }

      tweet = @tweets.sample
      words = tweet.text.split.reject do |word|
        @c.filtered.any? { |filtered_word| word.include? filtered_word }
      end.join ' '
      string = parse_tweet CGI.unescapeHTML(words)

      Akari::logger.info "fetched '#{string}' from '#{tweet.text}' via @#{tweet.user.screen_name} (#{tweet.id})"
      string
    end

    def parse_tweet text
      text = CGI.unescapeHTML text

      word_boundaries = text.indices(' ') << 0 << text.length
      start_index = word_boundaries.sample
      end_index = word_boundaries.select do |i|
        distance = (start_index - i).abs
        distance > 0 && distance < @c.max_string_length
      end.sample

      start_index, end_index = if end_index.nil?
        half = @c.max_string_length/2
        [0, rand(half) + half]
      else
        [start_index, end_index].sort
      end
      text[start_index..end_index].strip
    end

    def tweet_image path
      basename = File.basename path, '.*'
      words = Base64.urlsafe_decode64(basename).force_encoding('UTF-8')
      client.update_with_media words.daisuki, open(path)

      Akari::logger.info "tweeted '#{words}'"
    end

    def refollow
      followers = client.followers.take 20
      new_followers = followers.reject { |f| f.following || f.protected }.map(&:screen_name)
      client.follow new_followers

      Akari::logger.info "followed #{new_followers.join ','}" unless new_followers.empty?
    end
  end

  module Search
    require 'google-search'

    module_function
    def search query
      search_settings = { query: query, safe: 'active' }
      results = Google::Search::Image.new(search_settings).to_a
      uri = results.sample.uri unless results.empty?
      Akari::logger.info "searched '#{query}' and got '#{uri}'"
      uri
    end
  end

  module Image
    require 'RMagick'
    require 'open-uri'
    @c = Akari::config 'imagemagick'

    module_function
    # Returns an ImageList of the final image
    def akarify words, url
      image_file = open(url)
      canvas = Magick::ImageList.new.from_blob(image_file.read)
        .resize_to_fill(@c.width, @c.height)
      akari = Magick::ImageList.new(Dir["#{@c.akari_dir}/*.{png,gif}"].sample)
        .resize_to_fit(@c.width, @c.height)

      waai = words.daisuki "\n"
      c = @c
      caption = Magick::Image.read "caption:#{waai}" do |params|
        self.size = "#{c.width}x"
        self.gravity = Magick::SouthGravity
        self.stroke = 'black'
        self.fill = 'white'
        self.background_color = 'transparent'
        self.font = c.font
        self.pointsize = c.pointsize
      end.first

      canvas.composite! akari, Magick::SouthEastGravity, Magick::SrcOverCompositeOp
      akari.destroy!
      canvas.composite! caption, Magick::SouthGravity, Magick::SrcOverCompositeOp
      caption.destroy!
      image_file.close
      canvas
    end

  end
end


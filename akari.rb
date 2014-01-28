# encoding: utf-8

require_relative 'config'
require 'base64'
require 'logger'

class String
  def daisuki separator=' '
    "わぁい#{self}#{separator}あかり#{self}大好き"
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

    @client = Twitter::REST::Client.new do |config|
      config.consumer_key        = @c.consumer_key
      config.consumer_secret     = @c.consumer_secret
      config.access_token        = @c.access_token
      config.access_token_secret = @c.access_token_secret
    end

    module_function
    def get_words
      @tweets ||= @client
        .home_timeline(count: 200)
        .reject { |tweet| tweet.user.id == @c.user_id }

      tweet = @tweets.sample
      words = tweet.text.split.reject do |word|
        @c.filtered.any? { |filtered_word| word.include? filtered_word }
      end
      words = words[rand(words.length), 1 + rand(5)]
      string = words.join(' ')[0,40]
      Akari::logger.info "fetched '#{string}' from '#{tweet.text}' via @#{tweet.user.screen_name} (#{tweet.id})"
      string
    end

    def tweet_image path
      basename = File.basename path, '.*'
      words = Base64.urlsafe_decode64 basename
      @client.update_with_media words.daisuki, open(path)

      Akari::logger.info "tweeted '#{words}'"
    end

    def refollow
      ids = @client.follower_ids.to_a
      @client.follow ids
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
      image_file = open(url).read
      canvas = Magick::ImageList.new.from_blob(image_file)
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
      canvas.composite! caption, Magick::SouthGravity, Magick::SrcOverCompositeOp
    end

  end
end


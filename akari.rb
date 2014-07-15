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

  def get_words
    Akari::Tweets.get_words
  end

  def fetch
    words, url = loop do
      words = loop do
        words = get_words
        break words unless words.strip.empty?
      end

      url = Akari::Search::search words
      break words, url unless url.nil?
    end

    akarify_and_save words, url
  end

  def akarify_and_save words, url
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
    n = [@c.queue_size - image_paths.length, @c.queue_add_size].min
    n.times { fetch }
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
      words = CGI.unescapeHTML words
      string = rand < 0.7 ? random_noun(words) : parse_tweet(words)

      Akari::logger.info "fetched '#{string}' from '#{tweet.text}' via @#{tweet.user.screen_name} (#{tweet.url})"
      string
    end

    def parse_tweet text
      text = CGI.unescapeHTML text
      max_length = text.cjk? ? (@c.max_string_length/3).floor : @c.max_string_length

      word_boundaries = text.indices(' ') << 0 << text.length
      start_index = word_boundaries.sample
      end_index = word_boundaries.select do |i|
        distance = (start_index - i).abs
        distance > 0 && distance < max_length
      end.sample

      start_index, end_index = if end_index.nil?
        half = max_length/2.floor
        [0, half + rand(half)]
      else
        [start_index, end_index].sort
      end
      text[start_index..end_index].strip
    end

    require 'engtagger'
    # not really random noun, just longest noun phrase. oh god this code is such a mess
    def random_noun text
      return parse_tweet text if text.cjk?
      @tgr ||= EngTagger.new
      phrases = @tgr.get_words text
      if phrases.is_a? Hash
        phrase = phrases.keys.max_by(&:length).to_s.strip
        phrase.length < @c.max_string_length ? phrase : ''
      else
        ''
      end
    end

    def tweet_image path
      basename = File.basename path, '.*'
      words = Base64.urlsafe_decode64(basename).force_encoding('UTF-8')
      file = open path
      begin
        client.update_with_media words.daisuki, file
      rescue Twitter::Error::RequestTimeout
        Akari::logger.warn "twitter timed out for '#{words}'"
        sleep 30
        retry
      end

      file.close
      Akari::logger.info "tweeted '#{words}'"
    end

    def refollow
      followers = client.followers.take 20
      new_followers = followers.reject { |f| f.following || f.protected }.map(&:screen_name)
      return if new_followers.empty?

      client.follow new_followers
      Akari::logger.info "followed #{new_followers.join ', '}"
    end

    def unfollow
      followers = client.follower_ids.to_a
      friends = client.friend_ids.to_a
      to_unfollow = friends - followers

      return if to_unfollow.empty?
      client.unfollow to_unfollow
      names = client.users(to_unfollow).to_a.map(&:screen_name)
      Akari::logger.info "unfollowed #{names.join ', '}"
    end

    def sort_popularity tweets
      tweets.sort_by { |t| -t.favorite_count-t.retweet_count  }
    end

    def filter_by_day tweets, day = DateTime.now.to_date
      tweets.select { |t| t.created_at.to_date == day }
    end

    def to_html tweets
      li = tweets.map do |t|
        total = t.favorite_count + t.retweet_count
        count = "#{total} (#{t.retweet_count} RT + #{t.favorite_count} Favorites)"
        img = t.media.first.media_url.to_s unless t.media.empty?
        img = "<img src='#{img}' />"
        img = "<a href='#{t.url}'>#{img}</a>"
        inner = [count, img, t.text].map { |x| "<p>#{x}</p>" }.join
        "<li>#{inner}</li>"
      end.join
      "<ul>#{li}</ul>"
    end

    def top_tweets day = DateTime.now.to_date.prev_day, n = 10
      @own_tweets ||= client.user_timeline count: 200
      sort_popularity(filter_by_day @own_tweets, day).take n
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
      image_file = open url
      canvas = Magick::ImageList.new.from_blob(image_file.read)
        .resize_to_fill!(@c.width, @c.height)
      akari = Magick::ImageList.new(Dir["#{@c.akari_dir}/*.{png,gif}"].sample)
        .resize_to_fit!(@c.width, @c.height)
      canvas.composite! akari, Magick::SouthEastGravity, Magick::SrcOverCompositeOp
      akari.destroy!

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

      canvas.composite! caption, Magick::SouthGravity, Magick::SrcOverCompositeOp
      caption.destroy!
      image_file.close
      canvas
    end

  end
end


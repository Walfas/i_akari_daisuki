require_relative 'akari'

task :refollow do
  Akari::Tweets::refollow
end

task :unfollow do
  Akari::Tweets::unfollow
end

task :enqueue do
  Akari::enqueue
end

task :tweet do
  Akari::dequeue
  Akari::enqueue
end

task :akarify, :words, :url do |t, args|
  url = args[:url] || Akari::Search::search(args[:words])
  Akari::akarify_and_save args[:words], url
end

task :tumble, :day do |t, args|
  require_relative 'tumblr'
  args.with_defaults day: DateTime.now.to_date.prev_day.to_s

  tweets = Akari::Tweets.top_tweets Date.parse(args[:day])
  html = Akari::Tweets.to_html tweets
  Akari::Tumbles.post args[:day].to_s, html
end


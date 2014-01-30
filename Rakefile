require_relative 'akari'

task :refollow do
  Akari::Tweets::refollow
end

task :enqueue do
  Akari::enqueue
end

task :tweet do
  Akari::dequeue
  Akari::enqueue
end

task :test do
  require_relative 'tumblr'
  Akari::Tumbles.post 'test', 'test 2'
end

task :tumble, :day do |t, args|
  require_relative 'tumblr'
  args.with_defaults day: DateTime.now.to_date.to_s

  tweets = Akari::Tweets.top_tweets Date.parse(args[:day])
  html = Akari::Tweets.to_html tweets
  Akari::Tumbles.post args[:day].to_s, html
end


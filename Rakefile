require_relative 'akari'

task :refollow do
  Akari::Tweets::refollow
end

task :enqueue do
  Akari::enqueue
end

task :tweet do
  Akari::enqueue
  Akari::dequeue
end


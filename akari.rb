require 'twitter'
require 'RMagick'
require 'google-search'
require 'open-uri'
require 'tempfile'

WIDTH, HEIGHT = 640, 480
font = 'fonts/rounded-mplus-1c-bold.ttf'

client = Twitter::REST::Client.new do |config|
  config.consumer_key        = 'hi'
  config.consumer_secret     = 'hi'
  config.access_token        = 'hi'
  config.access_token_secret = 'hi'
end

tweets = client.home_timeline(count: 200, trim_user: true).reject {|t| t.user.id == 2312637570}
words = tweets.sample.text.split.reject do |word|
  filtered = %w{@ http:// https:// RT}
  filtered.any? { |filtered_word| word.include? filtered_word }
end
words = words[rand(words.length), 1 + rand(5)]

thing = words.join(' ')[0,40]

puts thing #DEBUG

#TODO: if thing is empty

# ==================================================== I'm dumb

def waai thing, newline = false
  separator = newline ? "\n" : ' '
  "わぁい#{thing}#{separator}あかり#{thing}大好き"
end

url = Google::Search::Image.new(query: thing, offset: 10, safe: 'active').to_a.sample.uri
canvas = Magick::ImageList.new.from_blob(open(url).read).resize_to_fill(WIDTH, HEIGHT)
akari = Magick::ImageList.new(Dir['./akari/*.{png,gif}'].sample).resize_to_fit(WIDTH, HEIGHT)

caption = Magick::Image.read "caption:#{waai thing, true}" do
  self.size = "#{WIDTH}x"
  self.gravity = Magick::SouthGravity
  self.stroke = 'black'
  self.fill = 'white'
  self.background_color = 'transparent'
  self.font = font
  self.pointsize = 42
end.first

canvas.composite! akari, Magick::SouthEastGravity, Magick::SrcOverCompositeOp
canvas.composite! caption, Magick::SouthGravity, Magick::SrcOverCompositeOp

output_image = "akari_#{Time.now.to_i}.jpg"
canvas.write output_image
client.update_with_media waai(thing), open(output_image)
File.delete(output_image)


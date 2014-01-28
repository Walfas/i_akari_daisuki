require 'configuration'

Configuration.for 'akari' do
  log_path 'log'

  queue_path 'queue'
  queue_size 50
  extension 'jpg'

  twitter {
    consumer_key        ''
    consumer_secret     ''
    access_token        ''
    access_token_secret ''

    filtered %w{@ http:// https:// RT}
    user_id 1234
  }

  imagemagick {
    width      640
    height     480
    pointsize  42
    font       'fonts/rounded-mplus-1c-bold.ttf'
    akari_dir  'akari'
  }
end


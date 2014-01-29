require 'configuration'

Configuration.for 'akari' do
  queue_path 'queue'
  queue_size 5
  extension 'jpg'

  log {
    path 'log/activity.log'
    num_files 10
    max_size 1024000
  }

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


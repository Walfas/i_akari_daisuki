require_relative 'akari'

module Akari
  module Tumbles
    require 'tumblr'
    @c = Akari::config 'tumblr'

    module_function
    def client
      @client ||= Tumblr::Client.new @c.hostname, {
        consumer_key: @c.consumer_key,
        consumer_secret: @c.consumer_secret,
        token: @c.oauth_token,
        token_secret: @c.oauth_token_secret
      }
    end

    def post title, body
      params = {
        type: :text,
        title: title,
        format: :html,
        body: body
      }
      resp = client.post(params).perform
      Akari::logger.info "tumbled '#{title}' response #{resp.body}"
    end
  end
end


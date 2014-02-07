require 'uri'
require 'net/http'
require 'json'

class Wordnik
  def initialize api_key
    @api_key = api_key
  end

  def get_word params = {}
    if @words.nil? || @words.empty?
      uri = URI.parse 'http://api.wordnik.com/v4/words.json/randomWords'
      uri.query = URI.encode_www_form(params.merge api_key: @api_key, hasDictionaryDef: false)
      body = Net::HTTP.get uri
      json = JSON.parse body
      @words = json.map { |j| j['word'] }
    end
    word = @words.pop.gsub '-', ' '
    Akari::logger.info "fetched '#{word}' from wordnik"
    word
  end
end


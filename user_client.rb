require 'json'
require 'rest-client'

class UserClient
  attr_reader :name

  def initialize name
    @name = name
    @log = []
  end

  def get_hello
    response = RestClient.get 'enter url here', {}
    resp_hash = JSON.parse(response)
    key = Time.now.to_s
    @log.push({key: resp_hash['hello']})
    if @log.length > 50
      log.shift
    end
    puts @log.inspect
  end
end

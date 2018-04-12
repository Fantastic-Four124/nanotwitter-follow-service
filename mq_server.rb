require 'bunny'
require 'sinatra'
require 'sinatra/activerecord'
require 'byebug'
require 'time_difference'
require 'time'
require 'json'
require 'redis'
require_relative 'models/follow'
require_relative 'models/follow'


#Dir[File.dirname(__FILE__) + '/api/v1/user_service/*.rb'].each { |file| require file }

class FollowerServer
  def initialize(id)
    @connection = Bunny.new(id)
    @connection.start
    @channel = @connection.create_channel
  end

  def start(queue_name)
    @queue = channel.queue(queue_name)
    @exchange = channel.default_exchange
    subscribe_to_queue
  end

  def stop
    channel.close
    connection.close
  end

  private

  attr_reader :channel, :exchange, :queue, :connection, :exchange2, :queue2

  def subscribe_to_queue
    queue.subscribe(block: true) do |_delivery_info, properties, payload|
      puts "[x] Get message #{payload}. Gonna do some user service about #{payload}"
      result = process(payload)
      puts result
      #byebug
      # exchange.publish(
      #   result,
      #   routing_key: properties.reply_to,
      #   correlation_id: properties.correlation_id
      # )
    end
  end

  # eg. {"leader_id":":5","user_id":"2","isFo":true}
  def process(follow_json)
    # follow_json['follower_id'], follow_json['leader_id'] get be integers
    # follow_json['isFo'] is bool
    # puts '#TrustTheProcess'
    # puts follow_json
    # return 'ojbk'
    if follow_json['isFo'] 
      follower_follow_leader(follow_json['follower_id'], follow_json['leader_id'])
    else
      follower_unfollow_leader(follow_json['follower_id'], follow_json['leader_id'])
    end
  end

  def follower_follow_leader(follower_id, leader_id)
    link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
    if link.nil?
        relation = Follow.new
        relation.user_id = follower_id
        relation.leader_id = leader_id
        relation.follow_date = Time.now
        relation.save
      end
  end
  
  def follower_unfollow_leader(follower_id, leader_id)
    link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
    if !link.nil?
        Follow.delete(link.id)
    end
  end

end


begin
  server = FollowerServer.new("amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO")

  puts ' [x] Awaiting RPC requests'
  server.start('rpc_queue')
  #server.start2('rpc_queue_hello')
rescue Interrupt => _
  server.stop
end
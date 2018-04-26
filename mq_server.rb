require 'bunny'
require 'sinatra/activerecord'
require 'byebug'
require 'time_difference'
require 'time'
require 'json'
require 'redis'
require 'set'
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
    puts '#TrustTheProcess'
    puts follow_json
    input = JSON.parse follow_json
    # return 'ojbk'
    if input['isFo'] 
      follower_follow_leader(input['user_id'], input['leader_id'])
    else
      follower_unfollow_leader(input['user_id'], input['leader_id'])
    end
  end

end

def follower_follow_leader(follower_id, leader_id)
  update_cache_follow(follower_id, leader_id, true)
  puts "follower_id: #{follower_id}"
  puts "leader_id: #{leader_id}"
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if link.nil?
    puts "follower_follow_leader"
    relation = Follow.new
    relation.user_id = follower_id
    relation.leader_id = leader_id
    relation.follow_date = Time.now
    relation.save
  end
end

def follower_unfollow_leader(follower_id, leader_id)
  update_cache_follow(follower_id, leader_id, false)
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if !link.nil?
    puts "follower_unfollow_leader"
    Follow.delete(link.id)
  end
end

def update_cache_follow(follower_id, leader_id, isFollowing)
  redis_leader_key = "#{leader_id} followers"
  redis_user_key = "#{follower_id} leaders"

  followers_of_leader, leaders_of_user = get_leaders_followers_map(redis_leader_key, redis_user_key)

  users_info_map, leader_info_map = get_user_obj_cache(follower_id, leader_id)

  if isFollowing 
    followers_of_leader[follower_id] = true
    leaders_of_user[leader_id] = true
    users_info_map['number_of_leaders'] += 1 if !users_info_map.nil? 
    leader_info_map['number_of_followers'] += 1 if !leader_info_map.nil?
  else # We dont love anymore
    followers_of_leader.delete(follower_id)
    leaders_of_user.delete(leader_id)
    leader_info_map['number_of_followers'] -= 1 if !leader_info_map.nil?
    users_info_map['number_of_leaders'] -= 1 if !users_info_map.nil?
  end

  $redis.set(redis_user_key, leaders_of_user.to_json)
  $redis.set(redis_leader_key, followers_of_leader.to_json)
  $redisUserServiceCache.set(follower_id, users_info_map.to_json) if !users_info_map.nil?
  $redisUserServiceCache.set(leader_id, leader_info_map.to_json) if !leader_info_map.nil?
end

def get_leaders_followers_map(redis_leader_key, redis_user_key)
  tmp1 = $redis.get(redis_leader_key)
  tmp2 = $redis.get(redis_user_key)

  if tmp1 == nil
    tmp1 = '{}'
    $redis.set("#{redis_leader_key} leaders", '{}')
  end

  if tmp2 == nil
    puts 'make new 2'
    tmp2 = '{}'
    $redis.set("#{redis_user_key} followers", '{}')
  end
  return JSON.parse(tmp1), JSON.parse(tmp2)
end

def get_user_obj_cache(follower_id, leader_id)
  tmp3 = $redisUserServiceCache.get(follower_id)
  tmp4 = $redisUserServiceCache.get(leader_id)

  if tmp3 == nil
    users_info_map = nil
  else 
    users_info_map = JSON.parse tmp3
  end
  
  if tmp4 == nil 
    leader_info_map = nil
  else
    leader_info_map = JSON.parse tmp4
  end
  # puts users_info_map
  # puts leader_info_map
  return users_info_map, leader_info_map
end

# begin
#   server = FollowerServer.new("amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO")

#   puts ' [x] Awaiting RPC requests'
#   server.start('rpc_queue')
#   #server.start2('rpc_queue_hello')
# rescue Interrupt => _
#   server.stop
# end
require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'redis'
require 'byebug'
require 'sinatra/cors'
require_relative 'models/follow'
require_relative 'models/user'
require_relative 'mq_client.rb'
require_relative 'local_env.rb' if ENV['RACK_ENV'] != 'production'
require_relative 'test_interface/test_interface.rb'

# Thread.new do
#   require_relative 'mq_server.rb'
# end

set :environment, :development
set :allow_origin, '*'
set :allow_methods, 'GET,HEAD,POST'
set :allow_headers, 'accept,content-type,if-modified-since'
set :expose_headers, 'location,link'

PREFIX = '/api/v1'
CLIENT = MQClient.new('rpc_queue', ENV['RABBIT_MQ'])
CLIENT_USR = MQClient.new('timeline_queue', ENV['RABBIT_MQ_USR'])

# ENV = {
#     "RABBITMQ_BIGWIG_REST_API_URL": "https://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@bigwig.lshift.net/management/179502/api",
#     "RABBITMQ_BIGWIG_RX_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10243/U1D3A0hgJsuO",
#     "RABBITMQ_BIGWIG_TX_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO",
#     "RABBITMQ_BIGWIG_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO"
#   }

configure do
  uri = URI.parse(ENV['REDIS_FOLLOW'])
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  uri2 = URI.parse(ENV['REDIS_USER'])
  $redisUserServiceCache = Redis.new(:host => uri2.host, :port => uri2.port, :password => uri2.password)
  
  #byebug
end


get '/' do
  send_file 'loaderiosetup.json'
end

get PREFIX do
  PREFIX.to_json
end

# For loader.io to auth
get '/loaderio-9afcad912efcc6db54e7a209047d1a20.txt' do
  send_file 'loaderioauth.txt'
end

# Get the leaders of :user_id
# returns a list of user object in json
# {users: [userid1, userid2, userid3, userid4 ...]}
get '/leaders/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  get_user_following(id, false)
end

get '/followers/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  get_user_following(id, true)
end

get '/status' do
  "number of follows: #{Follow.count}"
end

get PREFIX + '/:token/users/:id/follower-list' do
  # puts params
  input = JSON.parse $redisUserServiceCache.get(params['token']) # Get the user id
  if input
    return get_user_following(params['id'], true)
  else
    return {err: true}.to_json
  end
end

get PREFIX + '/:token/users/:id/leader-list' do
  # puts params
  input = JSON.parse $redisUserServiceCache.get(params['token']) # Get the user id
  if input
    return get_user_following(params['id'], false)
  else
    return {err: true}.to_json
  end
end

def get_user_object(id)
  cache = $redisUserServiceCache.get(id) 
  if cache.nil? 
    # TODO: If hit cache failed, save it to cache
    usrname = User.find(id).username
    
  else 
    usr_cache = JSON.parse cache
    usrname = usr_cache['username']
  end
  puts usrname
  { 'id': id, 'username': usrname }
end

def get_user_following(id, isFo)
  result = []
  cache = $redis.get("#{id} followers") if isFo
  cache = $redis.get("#{id} leaders") if !isFo
  if cache != nil 
    puts 'xxxxxxxxx'
    puts cache
    leaders = JSON.parse cache
    leaders.each_key { |usrid| result << get_user_object(usrid) }
  else 
    links = Follow.where(leader_id: id) if isFo
    links = Follow.where(user_id: id) if !isFo
    links.each do |follow| 
      result << get_user_object(follow.user_id) if isFo
      result << get_user_object(follow.leader_id) if !isFo
    end
    temp = {}
    links.each { |follow| temp[follow.user_id] = true } if isFo
    links.each { |follow| temp[follow.leader_id] = true } if !isFo
    $redis.set("#{id} followers", temp.to_json) if isFo
    $redis.set("#{id} leaders", temp.to_json) if !isFo
  end
  puts result
  result.to_json
end



# TODO
# Abstract get '/leaders/:user_id' and get '/followers/:user_id'
# Return a hash instead to optimize 
# TODO

post PREFIX + '/:token/users/:id/follow' do
  # puts params
  input = JSON.parse $redisUserServiceCache.get(params['token']) # Get the user id
  if input
    return fo(params['id'], input['id'], true)
  else
    return {err: true}.to_json
  end
end

post PREFIX + '/:token/users/:id/unfollow' do
  # puts params
  input = JSON.parse $redisUserServiceCache.get(params['token']) # Get the user id
  if input
    return fo(params['id'],input['id'], false)
  else
    return {err: true}.to_json
  end
end

post '/users/:id/follow' do
  puts params

  return fo(params['id'],params['me'],true)
end

post '/users/:id/unfollow' do
  puts params
  return fo(params['id'],params['me'],false)
end

# DANGER ZONE: calling this will clear the whole follow db
# and cache
post '/testinterface/clearall' do
  Follow.destroy_all
  'DONE'.to_json
end

def fo(leader_id, user_id, isFo)
  CLIENT.call( {"leader_id": leader_id, "user_id": user_id, "isFo": isFo}.to_json )
  CLIENT_USR.call( {"leader_id": leader_id, "user_id": user_id, "isFo": isFo}.to_json )
  puts 'Done fo'
  {err: false}.to_json
end

def protected! token
  return !$redisUserServiceCache.get(token).nil?
end
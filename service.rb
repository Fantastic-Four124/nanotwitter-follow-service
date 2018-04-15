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

Thread.new do
  require_relative 'mq_server.rb'
end

# set :port, 8080
set :environment, :development

# client = UserClient.new 'Alex'

set :allow_origin, '*'
set :allow_methods, 'GET,HEAD,POST'
set :allow_headers, 'accept,content-type,if-modified-since'
set :expose_headers, 'location,link'

PREFIX = '/api/v1'
CLIENT = MQClient.new('rpc_queue',"amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10243/U1D3A0hgJsuO")
  

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


# TODO
# Abstract get '/leaders/:user_id' and get '/followers/:user_id'
# Return a hash instead to optimize 
# TODO

# Get the leaders of :user_id
# returns a list of user object in json
# {users: [userid1, userid2, userid3, userid4 ...]}
get '/leaders/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  result = []
  cache = $redis.get("#{id} leaders")
  if cache != nil 
    puts 'xxxxxxxxx'
    puts cache
    leaders = JSON.parse cache
    leaders.each_key { |leader| result << leader }
  else 
    links = Follow.where(user_id: id)
    links.each do |follow| 
      result << get_user_object(follow.leader_id)
    end
    temp = {}
    links.each { |follow| temp[follow.leader_id] = true }
    $redis.set("#{id} leaders", temp.to_json)
  end
  
  puts result

  result.to_json
end

def get_user_object(id)
  cache = $redisUserServiceCache.get(id) 
  if cache.nil? 
    usrname = User.find(id).username
  else 
    usr_cache = JSON.parse chache
    usrname = usr_cache['username']
  end
  { 'id': id, 'username': usrname }
end

get '/followers/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  result = []
  cache = $redis.get("#{id} followers")
  if cache != nil 
    puts 'xxxxxxxxx'
    puts cache
    leaders = JSON.parse cache
    leaders.each_key { |leader| result << leader }
  else 
    links = Follow.where(leader_id: id)
    links.each do |follow| 
      result << get_user_object(follow.user_id)
    end
    temp = {}
    links.each { |follow| temp[follow.leader_id] = true }
    $redis.set("#{id} followers", temp.to_json)
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
  if params['pw'] == 'asdfg' 
    Follow.destroy_all
    'DONE'.to_json
  else
    'YOU DONT HAVE THE PERMISSION, DENIED.'.to_json
  end
end

def fo(leader_id, user_id, isFo)
  CLIENT.call({"leader_id": leader_id , "user_id": user_id, "isFo": isFo}.to_json)
  # client.stop
  puts 'Done fo'
  {err: false}.to_json
end

def protected! token
  return !$redis.get(token).nil?
end



# s = Rufus::Scheduler.singleton

# s.every '3s' do
#   puts 'sending request'
#   client.get_hello_cam
#   client.get_hello_zhou

# end

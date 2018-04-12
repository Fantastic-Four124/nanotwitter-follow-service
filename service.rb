require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'redis'
require 'byebug'
require 'sinatra/cors'
require_relative 'models/follow'
require_relative 'models/user'
require_relative 'mq_client.rb'
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

# ENV = {
#     "RABBITMQ_BIGWIG_REST_API_URL": "https://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@bigwig.lshift.net/management/179502/api",
#     "RABBITMQ_BIGWIG_RX_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10243/U1D3A0hgJsuO",
#     "RABBITMQ_BIGWIG_TX_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO",
#     "RABBITMQ_BIGWIG_URL": "amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10242/U1D3A0hgJsuO"
#   }

configure do
  uri = URI.parse("redis://rediscloud:pcmHnx1nymwXDbiBwe19McQd0eizEcGR@redis-18020.c14.us-east-1-2.ec2.cloud.redislabs.com:18020")
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  #byebug
end


get '/' do
  "READY".to_json
end

# Get the leaders of :user_id
# returns a list of user object in json
# {users: [userid1, userid2, userid3, userid4 ...]}
get '/leaders/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  # TODO: get from radis
  link = Follow.find(user_id: id).all
  puts link
  leader_id.to_json
end

get '/followers/:user_id' do
  input = params[:user_id]
  id = Integer(input)
  # TODO: get from radis
  link = Follow.find(leader_id: id).all
  puts link
  leader_id.to_json
  
end

post '/:token/users/:id/follow' do
  # puts params
  input = JSON.parse $redis.get(params['token']) # Get the user id
  if input
    return fo(params['id'], input['id'], true)
  else
    return {err: false}.to_json
  end
end

post '/:token/users/:id/unfollow' do
  # puts params
  input = JSON.parse $redis.get(params['token']) # Get the user id
  if input
    return fo(params['id'],input['id'],false)
  else
    return {err: false}.to_json
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

def fo(leader_id, user_id, isFo) 
  client = MQClient.new('rpc_queue',"amqp://YYs2R_X-:11ao3Y7jYnsXg_Ax-U5iA5LYCJ2YUlKp@swift-bartsia-719.bigwig.lshift.net:10243/U1D3A0hgJsuO")
  response = client.call({"leader_id": leader_id , "user_id": user_id, "isFo": isFo}.to_json)
  client.stop
  puts 'Done Unfo'
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

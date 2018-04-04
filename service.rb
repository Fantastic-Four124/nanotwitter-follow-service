require 'sinatra'
require 'sinatra/activerecord'
require 'json'
require 'redis'
require 'rufus-scheduler'
require_relative 'models/follow'
require_relative './user_client'

# set :port, 8080
set :environment, :development

# client = UserClient.new 'Alex'

configure do
  uri = URI.parse("redis://rediscloud:pcmHnx1nymwXDbiBwe19McQd0eizEcGR@redis-18020.c14.us-east-1-2.ec2.cloud.redislabs.com:18020")
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  #byebug
end


get '/' do
  "READY".to_json
end

# Get the followers of :user_id
# returns a list of user object in jason
# {users: [userid1, userid2, userid3, userid4 ...]}
get '/leaders/:user_id' do
  input = params[:user_id]
  leader_id = Integer(input)
  link = Follow.find(leader_id: leader_id).all
  puts "link.user_id:"
  puts link.user_id
  leader_id.to_json
end

get '/followers/:user_id' do
  input = params[:user_id]
  leader_id = Integer(input)
  leader_id.to_json
  

end

# Requires the input to have a user_id
post '/:token/users/:id/follow' do
  # puts params
  token = params['token']
  input = $redis.get(token)
  Thread.new{
    leader_id = Integer(input)
    follower_id = Integer(params['user_id'])
    follower_follow_leader(follower_id, leader_id)
    puts 'Done Updating DB'
  }
  'Start follow async'
end

# Requires the input to have a user_id
post '/users/:id/unfollow' do
  # puts params
  input = params["id"]
  Thread.new{
    leader_id = Integer(input)
    follower_id = Integer(params['user_id'])
    follower_unfollow_leader(follower_id, leader_id)
    puts 'Done Updating DB'
  }
  'Start follow async'
end



def follower_follow_leader(follower_id,leader_id)
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if link.nil?
      relation = Follow.new
      relation.user_id = follower_id
      relation.leader_id = leader_id
      relation.follow_date = Time.now
      relation.save
    end
end

def follower_unfollow_leader(follower_id,leader_id)
  link = Follow.find_by(user_id: follower_id, leader_id: leader_id)
  if !link.nil?
      Follow.delete(link.id)
  end
end

# s = Rufus::Scheduler.singleton

# s.every '3s' do
#   puts 'sending request'
#   client.get_hello_cam
#   client.get_hello_zhou

# end


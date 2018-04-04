require 'sinatra'
require 'json'
require 'rufus-scheduler'
require_relative './user_client'

set :port, 8080
set :environment, :development

# client = UserClient.new 'Alex'

get '/hello' do
  return_message = {}
  return_message[:hello] = 'hello, world! -- from Alex'
  return_message.to_json
end

# Get the followers of :user_id
# returns a list of user object in jason
# {users: [user1, user2, user3, user4 ...]}
get '/leaders/:user_id' do

end

get '/followers/:user_id' do
  
end

post '/users/:user_id/follow' do

end

post '/users/:user_id/unfollow' do

end


# s = Rufus::Scheduler.singleton

# s.every '3s' do
#   puts 'sending request'
#   client.get_hello_cam
#   client.get_hello_zhou

# end


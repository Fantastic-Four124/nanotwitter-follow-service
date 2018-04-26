require 'sinatra/activerecord'
require 'sinatra'
require 'byebug'
require 'faker' # fake people showing fake love
require 'json'
require_relative '../models/user'
require_relative '../models/follow'
require_relative 'test_interface_vars.rb'
require 'rest-client'

# This helper class handles all communications with other services
# and some general process of generating some data
class TestInterfaceHelper

  def get_username(user_id)
    last_response = RestClient.get PREFIX_USER_SERVICE + "/#{user_id}"
    if last_response.body == '{\"err\":true}'
      puts "user_id #{user_id} not in database!"
      return 'nil'
    else
      return last_response.body
    end
  end

  def get_random_userid
    # last_response = RestClient.get PREFIX_USER_SERVICE + "/test/random"
    # if last_response.code != 200
    #   last_response = RestClient.get PREFIX_USER_SERVICE + "/test/random"
    # end
    # puts last_response.body.to_i
    # return last_response.body.to_i
    1 + Random.rand(1000)
  end

  def create_new_user(user_id, username, password)
    # puts "id:#{user_id}, name:#{username}, password:#{password}"
    puts({ name: username, password: password }.to_json)
    RestClient.post PREFIX_USER_SERVICE + '/testcreate', {id: user_id, username: username, password: password, email: "xxx@brandeis.edu"}
  end

  # This has to return an id
  def create_new_user_noid(username, password)
    puts({ name: username, password: password }.to_json)
    response = RestClient.post PREFIX_USER_SERVICE + '/testcreate', { username: username, password: password, email: "xxx@brandeis.edu"}
    puts response.body.to_i
    return response.body.to_i
  end

  # def bulkload_new_user(result)
  #   puts result.to_json
  #   puts 'bulkbulkbulk'
  #   RestClient.post PREFIX_USER_SERVICE + '/bulkinsert', {'bulk': result}.to_json
  # end

  def follow(user_id, leader_id)
    RestClient.post PREFIX_FOLLOW_SERVICE + "/users/#{leader_id}/follow", {'me': user_id}
  end

  def unfollow(user_id, leader_id)
    RestClient.post PREFIX_FOLLOW_SERVICE + "/users/#{leader_id}/unfollow", {'me': user_id}
  end

  def reset_follows_id

  end

  def tweet(user_id, message, timestamps)
    jsonmsg = { "username": get_username(user_id), "id": user_id, "time": timestamps, 'tweet-input': message }
    RestClient.post PREFIX_TWEET_W_SERVICE + '/testing/tweets/new', jsonmsg
  end

  def bulk_tweet(tweets)
    jsonmsg = { "tweets": tweets.to_json }
    # puts jsonmsg
    RestClient.post PREFIX_TWEET_W_SERVICE + '/api/v1/tweets/bulkinsert', jsonmsg
  end

  def clear_all 
    destroy_all_follows
    destroy_all_users
    destroy_all_tweets
    # rake db:reset
  end

  def destroy_all_follows
    RestClient.post PREFIX_FOLLOW_SERVICE + '/testinterface/clearall', ""
  end

  def destroy_all_users
    RestClient.post PREFIX_USER_SERVICE + '/removeall', ""
  end

  def destroy_all_tweets
    RestClient.delete PREFIX_TWEET_W_SERVICE + '/api/v1/tweets/delete'
  end

  def recreate_testuser
    create_new_user(TESTUSER_ID, TESTUSER_NAME, TESTUSER_PASSWORD)
    # result = User.new(id: TESTUSER_ID, username: TESTUSER_NAME, password: TESTUSER_PASSWORD, email:TESTUSER_EMAIL).save
    # puts "Recreate testuser -> #{result}"
  end


  # What happen when you break up with someone.... ;(
  def remove_everything_about_testuser
    list_of_activerecords = [
      Follow.find_by(leader_id: TESTUSER_ID),
      Follow.find_by(user_id: TESTUSER_ID),
      User.find_by(username: TESTUSER_NAME)
    ]
    list_of_activerecords.each { |ar| destroy_and_save(ar) }
  end

  # Helper method, for active record object ONLY!
  def destroy_and_save(active_record_object)
    return if active_record_object == nil
    active_record_object.destroy
    active_record_object.save
  end

  def report_status
    status = [
      RestClient.get(PREFIX_TWEET_W_SERVICE + '/status'),
      RestClient.get(PREFIX_USER_SERVICE + '/test/status'),
      RestClient.get(PREFIX_FOLLOW_SERVICE + '/status')
    ].to_json
    return status
  end

  def get_testuser_timeline
    RestClient.get(PREFIX_TWEET_R_SERVICE + "/api/v1/testuser/users/#{TESTUSER_ID}/timeline")
  end

  def generate_code(number)
    charset = Array('A'..'Z') + Array('a'..'z')
    Array.new(number) { charset.sample }.join
  end

  def get_fake_password
    str = [true, false].sample ? Faker::Fallout.character : ''
    str += str + ([true, false].sample ? Faker::Food.dish  : '')
    str += ([true, false].sample ? Faker::Kpop.boy_bands : '')
    str.gsub(/\s/, '')
  end

  # Calling this will prevent activerecord from assigning the 
  # same id (which violates constrain)
  def reset_db_peak_sequence
    ActiveRecord::Base.connection.tables.each do |t|
      ActiveRecord::Base.connection.reset_pk_sequence!(t)
    end
  end

  def make_fake_tweets(user_ids, num)
    result = {}
    user_ids.each do |usr_id| 
      n = num
      while n.positive?
        txts = [
          Faker::Pokemon.name + ' uses ' + Faker::Pokemon.move,
          Faker::SiliconValley.quote,
          Faker::SiliconValley.motto,
          Faker::ProgrammingLanguage.name + ' is the best!',
          'I went to ' + Faker::University.name + '.',
          'Lets GO! ' + Faker::Team.name
        ]
        msg = txts.sample
  
        # # OLD VERSION
        # new_tweet = Tweet.new(user_id: usr_id, message: msg)
        # if new_tweet.save
        #   result[usr_id] = msg
        #   $redis.lpush('global', new_tweet.id)                # Cache it
        #   $redis.rpop('global') if $redis.llen('global') > 50 # Cache it
        # else
        #   puts 'Fake tweet Failed.'
        # end
        # # OLD VERSION
  
        result[usr_id] = msg
  
        tweet(usr_id, msg, '')
  
        n -= 1
      end
    end
    return result
  end
end 

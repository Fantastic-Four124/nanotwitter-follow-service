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
    last_response = RestClient.get PREFIX_USER_SERVICE + "/#{user_id}", ""
    if last_response.body == '{\"err\":true}'
      puts "user_id #{user_id} not in database!"
      return 'nil'
    else
      return last_response.body
    end
  end

  def get_random_userid
    last_response = RestClient.get PREFIX_USER_SERVICE + "/random", ""
    if last_response.code != 200
      last_response = RestClient.get PREFIX_USER_SERVICE + "/random", ""
    end
    puts last_response.body.to_i
    return last_response.body.to_i
  end

  def create_new_user(user_id, username, password)
    # puts "id:#{user_id}, name:#{username}, password:#{password}"
    puts({ name: username, password: password }.to_json)
    RestClient.get PREFIX_USER_SERVICE + '/testcreate', {id: user_id, password: password, email: "xxx@brandeis.edu"}.to_json
  end

  # This has to return an id
  def create_new_user_noid(username, password)
    puts({ name: username, password: password }.to_json)
    response = RestClient.get PREFIX_USER_SERVICE + '/testcreate', {id: user_id, password: password, email: "xxx@brandeis.edu"}.to_json
    puts response.body.to_i
    return response.body.to_i
  end

  # def bulkload_new_user(result)
  #   puts result.to_json
  #   puts 'bulkbulkbulk'
  #   RestClient.post PREFIX_USER_SERVICE + '/bulkinsert', {'bulk': result}.to_json
  # end

  def follow(user_id, leader_id)
    RestClient.post PREFIX_FOLLOW_SERVICE + "/users/#{leader_id}/unfollow", {'me': user_id}.to_json
  end

  def unfollow(user_id, leader_id)
    RestClient.post PREFIX_FOLLOW_SERVICE + "/users/#{leader_id}/follow", {'me': user_id}.to_json
  end

  def tweet(user_id, message, timestamps)
    jsonmsg = { "username": get_username(user_id), "id": user_id, "time": timestamps }.to_json
    RestClient.post PREFIX_TWEET_W_SERVICE + '/testing/tweets/new', jsonmsg
  end

  def clear_all 
    destroy_all_follows
    destroy_all_users
    destroy_all_tweets
  end

  def destroy_all_follows
    RestClient.post PREFIX_FOLLOW_SERVICE + '/testinterface/clearall', ""
  end

  def destroy_all_users
    RestClient.post PREFIX_USER_SERVICE + '/removeall', ""
  end

  def destroy_all_tweets
    RestClient.delete PREFIX_TWEET_W_SERVICE + '/api/v1/tweets/delete', ""
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
    # status = {
    #   'number of users': User.count,
    #   'number of tweets': Tweet.count,
    #   'number of follow': Follow.count,
    #   'Id of Test user': TESTUSER_ID
    # }
    # status
    return 'ojbk'
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
    while num.positive?
      txts = [
        Faker::Pokemon.name + ' uses ' + Faker::Pokemon.move,
        Faker::SiliconValley.quote,
        Faker::SiliconValley.motto,
        Faker::ProgrammingLanguage.name + ' is the best!',
        'I went to ' + Faker::University.name + '.',
        'Lets GO! ' + Faker::Team.name
      ]
      msg = txts.sample
      usr_id = user_ids.sample

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
      
      


      num -= 1
    end
    return result
  end
end 

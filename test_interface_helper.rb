require 'sinatra/activerecord'
require 'byebug'
require 'faker' # fake people showing fake love
require_relative 'models/user'
require_relative 'models/follow'

### Vars
TESTUSER_NAME = 'testuser'
TESTUSER_EMAIL = 'testuser@sample.com'
TESTUSER_PASSWORD = 'password'
NUMBER_OF_SEED_USERS = 1000
TESTUSER_ID = 3456 # The test user will always have 3456
RETRY_LIMIT = 15
### Vars

def recreate_testuser
  result = User.new(id: TESTUSER_ID, username: TESTUSER_NAME, password: TESTUSER_PASSWORD, email:TESTUSER_EMAIL).save
  puts "Recreate testuser -> #{result}"
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
  status = {
    'number of users': User.count,
    'number of tweets': Tweet.count,
    'number of follow': Follow.count,
    'Id of Test user': TESTUSER_ID
  }
  status
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

# Calling this will prevent activerecord from assigning the same id (which violates constrain)
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
    new_tweet = Tweet.new(user_id: usr_id, message: msg)
    if new_tweet.save
      result[usr_id] = msg
      $redis.lpush('global', new_tweet.id)                # Cache it
      $redis.rpop('global') if $redis.llen('global') > 50 # Cache it
    else
      puts 'Fake tweet Failed.'
    end
    num -= 1
  end
  return result
end



require 'sinatra'
require 'byebug'
require 'faker' # fake people showing fake love
require_relative 'test_interface_helper.rb'
require_relative 'test_interface_vars.rb'
HELPER = TestInterfaceHelper.new

get '/testinterface' do
  'ready'.to_json
end

# V
post '/test/reset/all' do
  HELPER.clear_all
  HELPER.report_status
end

# V
post '/test/reset/testuser' do
  HELPER.remove_everything_about_testuser
  HELPER.recreate_testuser
  HELPER.report_status.to_json
end

# Report the current version
# V
get '/test/version' do
  "Version: #{Version.VERSION}".to_json
end

# One page report
# How many users, follows, and tweets are there. What is the TestUser’s id
# V
get '/test/status' do
  HELPER.report_status
end

# Read from seed
# correct format should be /test/reset/standard?tweets=6
# V
post '/test/reset/standard?' do
  puts params
  input = params[:tweets]
  input2 = params[:users]
  input3 = params[:follows]
  HELPER.clear_all

  if params.length == 1
    num = -1 # -1 means no limit
  else
    num = Integer(input) # only load n tweets from seed data
    raise ArgumentError, 'Argument is smaller than zero' if num <= 0
  end

  if input2 == nil 
    user_num = 1000
  else
    user_num = Integer(input2)
  end

  if input3 == nil
    follow_num = 6000
  else
    follow_num = Integer(input3)
  end

  users_hashtable = Array.new(NUMBER_OF_SEED_USERS + 1) # from user_id to user_name
  users_hashtable[0] = TESTUSER_NAME

  usernames = load_all_users_from_seed user_num
  puts 'users done'
  GC.start

  load_all_follows_from_tweet follow_num
  puts 'follows done'
  GC.start
  

  load_all_tweets_from_tweet num, usernames
  puts 'tweets done'
  GC.start
  

  HELPER.recreate_testuser
  HELPER.reset_db_peak_sequence # reset sequence
  result = { 'Result': 'GOOD!', 'status': HELPER.report_status }
  result.to_json
end

# create u (integer) fake Users using faker. Defaults to 1.
# each of those users gets c (integer) fake tweets. Defaults to zero.
# Example: /test/users/create?count=100&tweets=5
post '/test/users/create?' do
  # HELPER.freset_db_peak_sequence # reset sequence
  input_count = params[:count]
  input_tweet = params[:tweets]
  count = Integer(input_count)
  tweet = Integer(input_tweet)
  puts 'Done faking users'
  # Fake tweets
  users_ids = Array.new(count)
  new_ppl = {}
  while count.positive?
    fake_ppl = Faker::Name.first_name + Faker::Name.last_name + HELPER.generate_code(5)
    # neo = User.new(username: fake_ppl, password: get_fake_password)
    new_userid = HELPER.create_new_user_noid(fake_ppl, HELPER.get_fake_password)

    if new_userid >= 0
      users_ids[count - 1] = new_userid
      new_ppl[new_userid] = fake_ppl
      # puts neo.id
    end
    count -= 1
  end

  # Fake tweets
  result = {
    'New Fake Users': new_ppl,
    'New Fake Tweets': HELPER.make_fake_tweets(users_ids, tweet),
    'Report': HELPER.report_status
  }
  puts result
  result.to_json
end


# user u generates t(integer) new fake tweets
# /test/user/22/follow?count=10
# v
post '/test/user/:user/tweets?' do
  puts params
  input_user = params[:user] # who
  input_user = TESTUSER_ID if input_user == 'testuser'
  input_count = params[:tweets]
  input_count = params[:count] if input_count == nil
  count = Integer(input_count) # number of fake tweets needed to generate
  result = {
    'New Fake Tweets': HELPER.make_fake_tweets([input_user], count),
    'Report': HELPER.report_status
  }
  result.to_json
end

# user u randomly follows people
# example: /test/user/22/follow?count=10
# V
post '/test/user/:user/follows?' do
  puts params
  input_user = params[:user] # who
  input_user = TESTUSER_ID if input_user == 'testuser'
  input_count = params[:count]
  count = Integer(input_count) # number of fake follow needed to generate
  fos = []
  while count.positive?
    leader = HELPER.get_random_userid
    puts leader
    puts input_user
    HELPER.follow(Integer(input_user), leader)
    fos << leader
    count -= 1
  end
  result = {
    "User #{input_user} follows": fos,
    'Report': HELPER.report_status
  }
  result.to_json
end

post '/user/testuser' do
  HELPER.get_testuser_timeline
end

post '/user/testuser/tweet' do
  HELPER.tweet(TESTUSER_ID, "This is a test tweet by test user." , '')
end

# people randomly follow each others
# example: /test/user/follow?count=10
# V
post '/test/user/follows?' do
  puts params
  input_count = params[:count]
  count = Integer(input_count) # number of fake follow needed to generate
  fos = []
  while count.positive?
    leader = HELPER.get_random_userid
    user = HELPER.get_random_userid
    if user == leader
      leader = HELPER.get_random_userid
      user = HELPER.get_random_userid
    end
    HELPER.follow(user, leader)
    fos << "#{user} follows #{leader}"
    count -= 1
  end
  result = {
    "Social Activities": fos,
    'Report': HELPER.report_status
  }
  result.to_json
end

def load_all_users_from_seed(limit)
  result = []
  usernames = {}
  f = File.open(ENV['FILE_USERS'], 'r')
  f.each do |line|
    break if limit <= 0
    str = line.split(',')
    uid = Integer(str[0]) # ID provided in seed, useless for our implementation for now
    name = str[1].gsub(/\n/, "")
    name = name.gsub(/\r/, "")
    usernames[uid] = name
    result << {'id': uid, 'username': name, 'email': "xxx@brandeis.edu","password_hash": HELPER.get_fake_password,"number_of_followers": 0, "number_of_leaders": 0}
    # result << [uid,name,"xxx@brandeis.edu",0,0]
    # users_hashtable[uid] = name
    HELPER.create_new_user(uid, name, HELPER.get_fake_password)
    limit -= 1
  end
  f.close()
  return usernames
  # HELPER.bulkload_new_user(result)
end

def load_all_follows_from_tweet(limit)
  f = File.open(ENV['FILE_FOLLOW'], 'r')
  HELPER.reset_follows_id
  f.each do |line|
    break if limit <= 0
    str = line.split(',')
    id1 = Integer(str[0]) # ID provided in seed, useless for our implementation for now
    id2 = Integer(str[1])
    puts "#{id1} fo #{id2}"
    ##
    link = Follow.find_by(user_id: id1, leader_id: id2)

    if link.nil?
      puts "follower_follow_leader"
      relation = Follow.new
      relation.user_id = id1
      relation.leader_id = id2
      relation.follow_date = Time.now
      relation.save
      limit -= 1
      HELPER.follow(id1, id2)
    end
    ##
  end
  f.close()
end



def load_all_tweets_from_tweet(limit, usernames)
  result = []
  f = File.open(ENV['FILE_TWEETS'], 'r')
  f.each do |line|
    break if limit <= 0 # enforce a limit if there is one
    str = line.split(',')
    id = str[0].to_i
    text = str[1]
    time_stamp = str[2]
    puts id
    puts text
    result << {"id": id, "username": usernames[id], "tweet-input": text, "timestamp": time_stamp} # for bulk insert 
    # HELPER.tweet(id, text, time_stamp) Insert one by one
    limit -= 1
  end
  f.close()
  HELPER.bulk_tweet(result)
  return result
end

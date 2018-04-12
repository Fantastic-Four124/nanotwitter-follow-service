require 'bunny'
require 'sinatra'
require 'sinatra/activerecord'
require 'byebug'
require 'time_difference'
require 'time'
require 'json'
require 'redis'
require_relative 'models/user'
# require_relative 'mq_server.rb'


class MQClient
  attr_accessor :call_id, :response, :lock, :condition, :connection,
                :channel, :server_queue_name, :reply_queue, :exchange

  def initialize(server_queue_name,id)
    @connection = Bunny.new(id,automatically_recover: false)
    @connection.start

    @channel = connection.create_channel
    @exchange = channel.default_exchange
    @server_queue_name = server_queue_name

    # setup_reply_queue
  end

  def call(n)

    @call_id = generate_uuid

    exchange.publish(n.to_s,
                     routing_key: server_queue_name,
                     correlation_id: call_id)

    # # wait for the signal to continue the execution
    # lock.synchronize { condition.wait(lock) }

    'ok'
  end

  def stop
    channel.close
    connection.close
  end

  private

  def setup_reply_queue
    @lock = Mutex.new
    @condition = ConditionVariable.new
    that = self
    @reply_queue = channel.queue('', exclusive: true)

    reply_queue.subscribe do |_delivery_info, properties, payload|
      if properties[:correlation_id] == that.call_id
        that.response = payload

        # sends the signal to continue the execution of #call
        that.lock.synchronize { that.condition.signal }
      end
    end
  end

  def generate_uuid
    # very naive but good enough for code examples
    "#{rand}#{rand}#{rand}"
  end
end

# client = MQClient.new('rpc_queue',ENV["RABBITMQ_BIGWIG_RX_URL"])


# count  = 0;
# user = User.new(username: "zhoutest4")
# user.password = "12345"
# to_do = {:function => "register", :candidate =>user.to_json}
# thr = Thread.new {
#     puts " [x] Requesting #{user.username} and #{user.password}"
#     response = client.call(to_do.to_json)
#     puts " [.] Got #{response}"
# }


# client.stop
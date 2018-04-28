require 'sinatra'
require 'sinatra/activerecord'
require 'minitest/autorun'
require 'rack/test'
require 'rake/testtask'
require 'json'
require_relative '../service.rb'
require 'rest-client'
require_relative '../models/follow'

PREFIX_FOLLOW_SERVICE = 'https://fierce-garden-41263.herokuapp.com'


class ServiceTest < Minitest::Test
  include Rack::Test::Methods

  def test_follow 
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/1/follow', {me: 2}
    rsb = RestClient.get PREFIX_FOLLOW_SERVICE + '/leaders/2'
    assert rsb.include? '"id":"1"'
  end

  def test_multiple_follow 
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/2/follow', {me: 1}
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/3/follow', {me: 1}
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/4/follow', {me: 1}
    rsb = RestClient.get PREFIX_FOLLOW_SERVICE + '/leaders/1'
    puts rsb
    assert (rsb.include? '"id":"2"') && (rsb.include? '"id":"3"') && (rsb.include? '"id":"4"')
  end

  def test_unfollow 
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/1/unfollow', {me: 2}
    rsb = RestClient.get PREFIX_FOLLOW_SERVICE + '/leaders/2'
    assert !(rsb.include? '"id":"1"')
  end

  def test_multiple_unfollow
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/2/unfollow', {me: 1}
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/3/unfollow', {me: 1}
    RestClient.post PREFIX_FOLLOW_SERVICE + '/users/4/unfollow', {me: 1}
    rsb = RestClient.get PREFIX_FOLLOW_SERVICE + '/leaders/1'
    puts rsb
    assert (!rsb.include? '"id":"2"') && (!rsb.include? '"id":"3"') && (!rsb.include? '"id":"4"')
  end

end
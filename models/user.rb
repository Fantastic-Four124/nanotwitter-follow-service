require 'bcrypt'

class User < ActiveRecord::Base
  validates :username,presence:true
  validates :password_hash,presence:true
  validates_uniqueness_of :username
  has_many :follows
  has_many :leaders, through: :follows  #,:source => :leader
  has_many :followings, :class_name => "Follow",:foreign_key => :leader_id
  has_many :followers, :through => :followings,:source => :user
  has_many :tweets
  has_many :tweets, through: :mentions

  include BCrypt

  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
  end

end

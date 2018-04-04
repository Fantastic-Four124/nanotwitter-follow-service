class Follow < ActiveRecord::Base
  include ActiveRecord::Calculations

    belongs_to :user
    belongs_to :leader, class_name: 'User'
end

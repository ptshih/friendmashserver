class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
end

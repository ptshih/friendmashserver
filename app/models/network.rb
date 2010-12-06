class Network < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :networks
end

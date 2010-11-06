class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  
  def createWithHash(user)
    if User.find_by_facebook_id(user[:id].to_s).nil?
      user = User.create({
        :facebook_id => user[:id],
        :full_name => user[:name], 
        :gender => user[:gender],
        :score => 1500,
        :wins => 0,
        :losses => 0,
        :win_streak => 0,
        :loss_streak => 0
      })
      User.find_by_facebook_id(user[:id].to_s).create_profile({
        :relationship_status => user[:relationship_status],
        :birthday => user[:birthday]
      })
    end
  end
end

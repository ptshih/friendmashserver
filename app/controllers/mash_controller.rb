class MashController < ApplicationController
  def random
    render :json => User.all(:order=>'RANDOM()',:limit=>1)[0]
  end
  
  def getNewMatchForUser
    user = User.find(params[:id])
    score = user.score
  end 
  
  def postFriends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
    currentUser = User.find_by_facebook_id(params[:id])
    params[:_json].each{ |user|
      if User.find_by_facebook_id(user[:id]).nil?
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
        user.create_profile({
          :relationship_status => user[:relationship_status],
          :birthday => user[:birthday]
        })
      end
    }
  end
  
  def result
    # report a match result to the server
    Rails.logger.info request.query_parameters.inspect
  end  
end

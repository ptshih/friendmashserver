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
      User.createWithHash(user)
    }
  end
  
  def result
    # report a match result to the server
    Rails.logger.info request.query_parameters.inspect
  end  
end

class MashController < ApplicationController
  def random
    render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
  end
  
  def getMatchForUser
     render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
  end 
  
  def postFriends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
    currentUser = User.find_by_facebook_id(params[:id])
    params[:_json].each{ |user|
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
        user.reload
        user.create_profile({
          :relationship_status => user[:relationship_status],
          :birthday => user[:birthday]
        })
      end
    }
    render:text => {:success=>true}.to_json
  end
  
  def result
    # report a match result to the server 
    Rails.logger.info request.query_parameters.inspect
    
    winner = User.find_by_facebook_id(params[:w].to_s)
    loser  = User.find_by_facebook_id(params[:l].to_s)
    
    winner.update_attributes(:wins => winner[:wins]+1 )
    winner.update_attributes(:score => winner[:score]+15 )
    
    loser.update_attributes(:losses => loser[:losses]+1 )
    loser.update_attributes(:score => loser[:score]-15 )
  end  
end

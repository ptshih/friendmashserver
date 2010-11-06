class MashController < ApplicationController
  def random
    @users = User.all(:order=>'RANDOM()',:limit=>1)
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
      format.json  { render :json => @users }
    end
  end
  
  def postFriends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
  end
  
  def result
    # report a match result to the server
    Rails.logger.info request.query_parameters.inspect
  end
  
end

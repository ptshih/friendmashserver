class MashController < ApplicationController
  def random
    @users = User.all
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
      format.json  { render :json => @users }
    end

  end
  
  def result
  end
end

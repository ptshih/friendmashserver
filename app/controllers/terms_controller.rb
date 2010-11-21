class TermsController < ApplicationController
  
  # GET /terms
  # GET /terms.xml
  def index
    @title = "Terms of Service"
    respond_to do |format|
      format.html # index.html.erb
    end
  end
end

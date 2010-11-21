class PrivacyController < ApplicationController
  # GET /privacy
  # GET /privacy.xml
  def index
    @title = "Privacy Policy"
    respond_to do |format|
      format.html # index.html.erb
    end
  end
end

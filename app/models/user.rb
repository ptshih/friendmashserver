class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  has_one :token, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  has_many :networks, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  has_many :employers, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  has_many :schools, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  has_many :results, :foreign_key => 'facebook_id', :primary_key => 'facebook_id', :inverse_of => :user
  
  # When migrating new default values, it doesnt zero it out for some reason
  #
  # User.all.each do |u| u.update_attributes(:score_network => 1500, :wins_network => 0, :losses_network => 0, :win_streak_network => 0, :loss_streak_network => 0) end
  # User.all.each do |u| u.update_attributes(:win_streak_max => 0, :loss_streak_max => 0, :win_streak_max_network => 0, :loss_streak_max_network => 0) end
  #
  
  def reloadMyGender
    # UNUSED
    
    # Console Cmd:
    # User.all(:conditions=>'gender IS NULL',:include=>:profile).each do |u| u.reloadMyGender end
    
    # return if self.profile.nil? || self.profile[:first_name].nil?
    begin
      return nil if not self[:gender].nil? # don't perform if gender already exists
      firstname = self.profile[:first_name].split(' ')[0].downcase
      
      result = Name.where("name = '#{firstname}'")
      
      
      if result.count == 0
        puts "could not find a gender for #{firstname}"
      elsif result.count > 1
        foundGender = result.first.score > result.last.score ? result.first.gender : result.last.gender
        puts "found two genders for #{firstname}, returning #{foundGender}"
        self.update_attribute('gender',foundGender)
      else
        # found a single entry
        puts "found a gender for #{firstname} - #{result.first.gender}"
        self.update_attribute('gender',result.first.gender)
      end
      
      # html = HTTPClient.new.get_content("http://www.gpeters.com/names/baby-names.php?name=#{firstname}&button=Go")
      # if html.include?("It's a boy")
      #   puts "found a boy! #{firstname}"
      #   self.update_attribute('gender','male')
      # elsif html.include?("It's a girl")
      #   puts "found a girl! #{firstname}"
      #   self.update_attribute('gender','female')
      # else
      #   puts "could not detect gender for #{firstname}"
      # end
    rescue
      puts "nope, didnt work for #{firstname}"
    end
    return nil
  end
  
  # This method calls facebook to retrieve friends list from all user's who have a token
  # Then updates the gender field for all the friends
  # This was written because our gender matcher screwed up our DB
  # User.all.each do |u| u.refreshMyGenderFromFacebook if not u.token.nil? end
  def refreshMyGenderFromFacebook
    # UNUSED
    begin
      fields = Hash.new
      fields["fields"] = "id,name,gender"
      friends = friends(fields)
      
      friends.each do |f|
        u = User.find_by_facebook_id(f['id'])
        puts "updating gender for #{u[:facebook_id]} with #{f['gender']}" if not f['gender'].nil?
        u.update_attribute('gender',f['gender'])
      end
      puts "successfully updated friends gender for #{u[:facebook_id]}"
    rescue
      puts "something went wrong for user: #{self.facebook_id} with name: #{self.profile.full_name}"
    end
    return nil
  end
  
  
  def picture(size=nil)
    # returns first image in profile album, defaults to original size
    p = self.pictures.first
    case size
      when 'thumb'
        p['picture']
      when 'original'
        p['source']
      else
        p['source']
    end
  end
  
  def pictures
    self.profileAlbum['data']
  end
  
  # calls albums, loops through and finds first album where name includes "Profile"
  def profileAlbum
    aid = self.albums.select{|a| a['name'].include?('Profile')}[0]['id']
    self.fbCall("/#{aid}/photos")
  end
  
  def albums 
    self.fbCall("/#{self['facebook_id']}/albums/")['data']
  end
  
  def friends(params = {})
    self.fbCall("/#{self['facebook_id']}/friends/",params)['data']
  end
  
  def fbprofile
    self.fbCall("/#{self['facebook_id']}")
  end
  
  # this "looks up" the original friend that loaded this user, or itself if it has a token
  def originalFriend    
    self.token ? self : User.find_by_facebook_id(Network.find_by_friend_id(self['facebook_id'])['facebook_id'])
  end
  
  # if necessary, lets find the original friend that loaded this users data and use their token instead
  def fbCall(path,params = {})
    params['access_token'] = self.token ? self.token['access_token'] : self.originalFriend.token['access_token']
    getJSON("https://graph.facebook.com#{path}", params)
  end
  
  def getJSON(path,params)
    begin
      # JSON.parse(HTTPClient.new.get_content(path,params))
      # JSON.parse(Zlib::GzipReader.new(StringIO.new(HTTPClient.new.get_content(path,params,extheader))).read)
      # it seems the gzip response is unreliable, so we need to check the response encoding
      
      extheader = { 'Accept-Encoding' => 'gzip' }
      response = HTTPClient.new.get(path,params,extheader)
      
      # p response.content
      # contentType = response.contenttype
      encoding = response.header["Content-Encoding"]
      puts "Encoding: #{encoding}"
      
      if encoding.include? "gzip"
        puts "found gzip response"
        parsedResponse = JSON.parse(Zlib::GzipReader.new(StringIO.new(response.content)).read)
        puts "done parsing"
      else
        puts "found text response"
        parsedResponse = JSON.parse(response.content)
      end
      
      return parsedResponse
    rescue => ex
      puts ex
      puts "found invalid token!!! #{path} #{params}"
    end
  end
  
end

class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_one :token, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :network, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :employer, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :school, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :result, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  
  def reloadMyGender
    # Console Cmd:
    # User.all(:conditons=>'gender IS NULL',:include=>:profile).each do |u| u.delay.reloadMyGender end
    
    # return if self.profile.nil? || self.profile[:first_name].nil?
    begin
      return nil if not self[:gender].nil? # don't perform if gender already exists
      firstname = self.profile[:first_name].split(' ')[0]
      html = HTTPClient.new.get_content("http://www.gpeters.com/names/baby-names.php?name=#{firstname}&button=Go")
      if html.include?("It's a boy")
        puts "found a boy! #{firstname}"
        self.update_attribute('gender','male')
      elsif html.include?("It's a girl")
        puts "found a girl! #{firstname}"
        self.update_attribute('gender','female')
      else
        puts "could not detect gender for #{firstname}"
      end
    rescue
      puts 'nope, didnt work'
    end
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
      JSON.parse HTTPClient.new.get_content(path,params)
    rescue
      puts "found invalid token!!! #{path} #{params} #{ex}"
    end
  end
  
end

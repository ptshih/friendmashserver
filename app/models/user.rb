class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_one :token, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :network, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :employer, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :school, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :result, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  
  def reloadMyGender
    return if self.profile[:first_name].nil?
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
  end
  
end

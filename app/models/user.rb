class User < ActiveRecord::Base
  has_one :profile, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_one :token, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :network, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :employer, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :school, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  has_many :result, :foreign_key => 'facebook_id', :primary_key => 'facebook_id'
  
  def reloadMyGender
    firstname = self.name.split(' ')[0]
    html = HTTPClient.new.get_content("http://www.gpeters.com/names/baby-names.php?name=#{name}&button=Go")
    if html.include?("It's a boy")
      puts "found a boy! #{firstname}"
      self.set_attribute('gender','male')
    elsif html.include?("It's a girl")
      puts "found a girl! #{firstname}"
      self.set_attribute('gender','female')
    end
  end
  
end

class PopulateMissingGenders < Struct.new(:friendIdArray) 
  def perform
    puts "PopulateMissingGenders called"
    
    friendIdArray.each do |friendId|
      populate_missing_gender(friendId)
    end
    
  end
  
  def populate_missing_gender(facebookId)
    # Console Cmd:
    # User.all(:conditions=>'gender IS NULL',:include=>:profile).each do |u| u.reloadMyGender end
    
    # return if self.profile.nil? || self.profile[:first_name].nil?
    begin
      user = User.find_by_facebook_id(facebookId)
      
      return nil if not user[:gender].nil? # don't perform if gender already exists
      firstname = user.profile[:first_name].split(' ')[0].downcase
      
      result = Name.where("name = '#{firstname}'")
      
      if result.count == 0
        puts "could not find a gender for #{firstname}"
      elsif result.count > 1
        foundGender = result.first.score > result.last.score ? result.first.gender : result.last.gender
        puts "found two genders for #{firstname}, returning #{foundGender}"
        user.update_attribute('gender',foundGender)
      else
        # found a single entry
        puts "found a gender for #{firstname} - #{result.first.gender}"
        user.update_attribute('gender',result.first.gender)
      end
    rescue
      puts "nope, didnt work for #{firstname}"
    end
    return nil
  end
end
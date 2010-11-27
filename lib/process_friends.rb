class ProcessFriends < Struct.new(:facebookId) 
  require 'generate_second_degree'
  require 'populate_missing_genders'
  
  def perform
    puts "ProcessFriends called for user with id: #{facebookId}"
    
    # get the current user
    user = User.find_by_facebook_id(facebookId)
    
    # Get first degree friends from FB
    fields = Hash.new
    fields["fields"] = "id,first_name,last_name,name,gender,education,work,locale"
    firstDegreeFriends = user.friends(fields)
    
    # insert the first degree friends into the DB as degree 1
    process_friends(facebookId, firstDegreeFriends, 1)
    
  end
  
  def process_friends(facebookId = nil, friends = nil, degree = 1)
    return nil if friends.nil? || facebookId.nil?

    friendIdArray = Array.new

    friends.each do |friend|
      create_user(friend)

      # Insert friend into friendIdArray if not myself
      if not facebookId == friend['id']
        friendIdArray << friend['id']
      end
    end

    # Generate first degree network for this user
    generate_network(facebookId, friendIdArray, degree)
    
    # Populate any missing genders
    Delayed::Job.enqueue PopulateMissingGenders.new(friendIdArray)

    # Calculate the 2nd degree network table for the newly created user
    Delayed::Job.enqueue GenerateSecondDegree.new(facebookId)
  
    # Whenever a new user is created or friends list is processed
    # We should re-calculate the 2nd degree network table 
    #   for all people who have logged in before (token table) who are friends of this new user
    # 
    # Token.select('facebook_id').where("facebook_id IN ('548430564','1217270')").map do |x| x.facebook_id end
    friendIdString = "\'" + friendIdArray.split(',').join("\',\'") + "\'"
    tokenIdArray = Token.select('facebook_id').where("facebook_id IN (#{friendIdString})").map do |u| u.facebook_id end
    
    tokenIdArray.each do |tokenId|
      if not tokenId == facebookId
        Delayed::Job.enqueue GenerateSecondDegree.new(tokenId)
      end
    end
  end
  
  def create_user(fbUser)
    user = User.find_by_facebook_id(fbUser['id'])
    if user.nil?
      User.new do |u|
        u.facebook_id = fbUser['id']
        u.gender = fbUser['gender'].nil? ? nil : fbUser['gender']
        u.score = 1500
        u.wins = 0
        u.wins_network = 0
        u.losses = 0
        u.losses_network = 0
        u.win_streak = 0
        u.win_streak_network = 0
        u.loss_streak = 0
        u.loss_streak_network = 0
        u.win_streak_max = 0
        u.loss_streak_max = 0
        u.win_streak_max_network = 0
        u.loss_streak_max_network = 0
        u.save
      end
      profile = Profile.find_by_facebook_id(fbUser['id'])
      if profile.nil?
        Profile.new do |p|
          p.facebook_id = fbUser['id']
          p.first_name = fbUser['first_name'].nil? ? nil : fbUser['first_name']
          p.last_name = fbUser['last_name'].nil? ? nil : fbUser['last_name']
          p.full_name = fbUser['name']
          p.votes = 0
          p.votes_network = 0
          p.save
        end
      end

      fbUser['education'].each do |education|
        School.new do |s|
          s.facebook_id = fbUser['id']
          s.school_id = education['school']['id']
          s.school_name = education['school']['name']
          s.save
        end
      end if not fbUser['education'].nil?

      fbUser['work'].each do |work|
        Employer.new do |e|
          e.facebook_id = fbUser['id']
          e.employer_id = work['employer']['id']
          e.employer_name = work['employer']['name']
          e.save
        end
      end if not fbUser['work'].nil?
    else
      user.update_attributes(
      :gender => fbUser['gender']
      )
    end
  end

  def generate_network(facebookId, friendIdArray, degree = 1)
#    friendIdArray = ["1217270","1217767","1209924"]
    # This method generates a network link table of user -> friend with degree = 1
    puts "Generate #{degree} degree network link table for user with id: #{facebookId}"

    friendIdArray.each do |friendId|
      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => friendId }]).empty?
        network = Network.create(
          :facebook_id => facebookId,
          :friend_id => friendId, 
          :degree => degree
        )
      end
    end
  end
end
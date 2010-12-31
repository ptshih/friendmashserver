class ProcessFriends < Struct.new(:facebookId) 
  # require 'generate_second_degree'
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
    process_friends(facebookId, firstDegreeFriends)
  end
  
  def process_friends(facebookId = nil, friends = nil)
    return nil if friends.nil? || facebookId.nil?

    friendIdArray = Array.new
    missingGenderArray = []
    createNewUser = []
    createNewProfile = []
    createNewSchool = []
    createNewEmployer = []
    friends.each do |friend|
      # Create a User entity for each friend
      # create_user(friend)
      
      # Seminew way of bulkinsert models into database
      #createNewUser << User.new(:facebook_id=>friend['id'].to_i, :gender=>friend['gender'])
      #createNewProfile << Profile.new(:facebook_id=>friend['id'].to_i,:first_name=>friend['first_name'],:last_name=>friend['last_name'],:full_name=>friend['name'])
      
      # New, faster way of bulk inserting in database
      # Create new user
      createNewUser << [friend['id'].to_i, friend['gender']]
      # Create new profile
      createNewProfile << [friend['id'].to_i, friend['first_name'], friend['last_name'], friend['name']]
      # Create Schools for user if exists
      friend['education'].each do |education|
        if not education['school'].nil?
          createNewSchool << [education['school']['id'].to_i, education['school']['name']]
        end
      end if not friend['education'].nil?
      # Create Employers for user if exists
      # friend['work'].each do |work|
      #   if not work['employer'].nil?
      #     createNewEmployer << [work['employer']['id'].to_i, work['employer']['name']]
      #   end
      # end if not friend['work'].nil?
      
      # Insert friend into friendIdArray if not myself
      if not facebookId == friend['id']
        friendIdArray << friend['id']
      end
      
      # Populate gender only for nil
      if friend['gender'].nil?
        missingGenderArray<< friend['id']
      end
    end
    #User.import createNewUser
    #Profile.import createNewProfile
    
    usercolumns=[:facebook_id, :gender]
    User.import usercolumns,createNewUser, :validate => false
    profilecolumns = [:facebook_id, :first_name, :last_name, :full_name]
    Profile.import profilecolumns,createNewProfile, :validate => false
    schoolcolumns = [:school_id, :school_name]
    School.import schoolcolumns,createNewSchool, :validate => false
    employercolumns = [:employer_id, :employer_name]
    Employer.import employercolumns,createNewEmployer, :validate => false
    
    # Generate first degree network for this user
    generate_network(facebookId, friendIdArray, 1)
    
    # Populate any missing genders
    Delayed::Job.enqueue PopulateMissingGenders.new(missingGenderArray)
  end
  
  def create_user(fbUser)
    user = User.find_by_facebook_id(fbUser['id'].to_i)
    if user.nil?
      # If user with this facebookId does not exist, create a new one
      user = User.create(
        :facebook_id => fbUser['id'].to_i,
        :gender => fbUser['gender'].nil? ? nil : fbUser['gender']
      )
      # Create a profile for the user
      profile = user.create_profile(
        :first_name => fbUser['first_name'].nil? ? nil : fbUser['first_name'],
        :last_name => fbUser['last_name'].nil? ? nil : fbUser['last_name'],
        :full_name => fbUser['name'].nil? ? nil : fbUser['name']
      )
      # Create Schools for user if exists
      fbUser['education'].each do |education|
        if not education['school'].nil?
          school = user.schools.create(
            :school_id => education['school']['id'].nil? ? nil : education['school']['id'].to_i,
            :school_name => education['school']['name'].nil? ? nil : education['school']['name']
          )
        end
      end if not fbUser['education'].nil?
      # Create Employers for user if exists
      # fbUser['work'].each do |work|
      #   if not work['employer'].nil?
      #     employer = user.employers.create(
      #       :employer_id => work['employer']['id'].nil? ? nil : work['employer']['id'].to_i,
      #       :employer_name => work['employer']['name'].nil? ? nil : work['employer']['name']
      #     )
      #   end
      # end if not fbUser['work'].nil?
    else
      # If user already exists, update their gender
      user.update_attributes(
        :gender => fbUser['gender']
      )
      # Update schools
      # Update employers
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
class Network < ActiveRecord::Base
  def self.lol
    puts "lol"
  end
  
  def self.generateFirstDegreeNetworkForUser(facebookId, friendIdArray)
#    friendIdArray = ["1217270","1217767","1209924"]
    # This method generates a network link table of user -> friend with degree = 1
    puts "Generate 1st degree network link table for user with id: #{facebookId}"

    friendIdArray.each do |friendId|
      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => friendId }]).empty?
        Network.create({
          :facebook_id => facebookId,
          :friend_id => friendId, 
          :degree => 1
        })
      end
    end
  end

  def self.generateSecondDegreeNetworkForUser(facebookId)
    # This method appends to the network link table of user -> friendoffriend with degree = 2
    # It checks inside the network table for all friends of a friend and creates a record for the user -> friendoffriend with degree = 2
    # This only works if the friend of the user has also logged in once and generated his/her firstDegree network also (has uploaded friends list)
    
=begin
    How to map-reduce to get a user's 1st and 2nd degree network

    Create a link table between a facebook_id to a friend_id and a degree

    Data Model:
    | facebook_id | friend_id | degree |
    | 12345678901 | 123121412 | 1      |
    | 12345678901 | 235144319 | 2      |

    hash map of all my friends, mark the value as one (keyed of userid)
    traverse every friend and try to insert into hash map
    if a 2nd degree friend already exists in hash map, ignore
    if a 2nd degree friend does not exist, insert into hash map with a value of 2
=end
    
    puts "Generate 2nd degree network link table for user with id: #{facebookId}"

    firstDegree = Network.where(["facebook_id = :facebook_id AND degree = 1", { :facebook_id => facebookId } ])

    # p firstDegree

#    firstDegree = User.all(:conditions => "facebook_id = '{facebookId}'")

    firstHash = {}
    secondHash = {}

    firstDegree.each do |firstDegreeFriend|
      firstHash.store(firstDegreeFriend.friend_id, 1)
    end

    firstDegree.each do |firstDegreeFriend|
      secondDegree = Network.where(["facebook_id = :first_id AND degree = 1", { :first_id => firstDegreeFriend.friend_id } ])

      secondDegree.each do |secondDegreeFriend|
        if not firstHash.has_key?(secondDegreeFriend.friend_id)
          secondHash.store(secondDegreeFriend.friend_id, 2)
        end

        # puts secondDegreeFriend.friend_id
      end
    end

    secondHash.each { |key, value|
      puts "#{key} - #{value}"

      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => key }]).empty?
        Network.create({
          :facebook_id => facebookId,
          :friend_id => key, 
          :degree => value
        })
      end

    }

    p secondHash

    return nil
  end
end

class GenerateSecondDegree < Struct.new(:facebookId)
  # This delayed job method will create entries for a given user's 2nd degree friend connections
  # We traverse the current user's friends list by requesting from the network table the user's 1st degree friends
  # Create a key-value hash of all 1st degree friends in a temporary hash
  # Create an empty key-value hash for 2nd degree friends
  # If a 2nd degree friend is already a 1st degree, we ignore it (want that person to still be 1st degree)
  # If a 2nd degree friend is not a 1st degree, add it to 2nd degree hash
  # For each entity in the 2nd degree hash, create a Networks record with degree = 2
  
  # How to map-reduce to get a user's 1st and 2nd degree network
  # 
  #  Create a link table between a facebook_id to a friend_id and a degree
  # 
  #  Data Model:
  #  | facebook_id | friend_id | degree |
  #  | 12345678901 | 123121412 | 1      |
  #  | 12345678901 | 235144319 | 2      |
  # 
  #  hash map of all my friends, mark the value as one (keyed of userid)
  #  traverse every friend and try to insert into hash map
  #  if a 2nd degree friend already exists in hash map, ignore
  #  if a 2nd degree friend does not exist, insert into hash map with a value of 2

  def perform    
    puts "Generate 2nd degree network table for user with id: #{facebookId}"

    # Find the current user's 1st degree friends
    firstDegree = Network.where(["facebook_id = :facebook_id AND degree = 1", { :facebook_id => facebookId } ])

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

      end
    end

    secondHash.each do |key, value|
      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => key }]).empty?
        network = Network.create(
          :facebook_id => facebookId,
          :friend_id => key, 
          :degree => value
        )
      end
    end
    return nil
  end
end
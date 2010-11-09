class MashController < ApplicationController
  def random
    # Find two random people who have similar scores
    Rails.logger.info request.query_parameters.inspect
    
    # puts params[:recents].length
    
    # params[:mode]
    # 0 - ALL
    # 1 - NETWORK
    if params[:mode] == 1
      networkIds = nil
    else
      networkIds = []
      Network.where("facebook_id = '#{params[:id]}'").each do |network|
        networkIds << network.friend_id
      end
      p networkIds
      if networkIds.empty?
        networkIds = nil
      else
        networkIds = '\'' + networkIds.split(',').join('\',\'')+'\'' 
      end
    end
    
    # MySQL uses RAND, SQLLite uses RANDOM
    if Rails.env == "production"
      randQuery = 'RAND()'
    else
      randQuery = 'RANDOM()'
    end
    
    # Randomly choose a user from the DB with a CSV of excluded IDs
    if params[:recents].length == 0
      recentIds = nil
      if networkIds.nil?
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>randQuery,:limit=>1,:include=>[:profile])[0]
      else
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id IN (#{networkIds})",:order=>randQuery,:limit=>1,:include=>[:profile])[0]
      end
    else
      recentIds = '\'' + params[:recents].split(',').join('\',\'')+'\'' 
      if networkIds.nil?
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id NOT IN (#{recentIds})",:order=>randQuery,:limit=>1,:include=>[:profile])[0]
      else
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id NOT IN (#{recentIds}) AND facebook_id IN (#{networkIds})",:order=>randQuery,:limit=>1,:include=>[:profile])[0]
      end
    end
    
    opponent = findOpponentForUser(randomUser.score, params[:gender], randomUser.facebook_id, recentIds, networkIds)
    response = [randomUser.facebook_id, opponent.facebook_id]
    render :json => response
  end
  
  def findOpponentForUser(desiredScore, gender, currentId = nil, recentIds = nil, networkIds = nil)
    # First hit the DB with a CSV of excluded IDs and a match_score +/- match_range
    # Fetch an array of valid IDs from DB who match the +/- range from the current user's score
    # Perform a binary search on the array to find the best possible opponent
    # Return a single opponent
    
    # In the future range should be dynamically calculated based on normal distribution of desired score
    # range = calculateRange(desiredScore)
    range = 500
    
    if recentIds.nil?
      if networkIds.nil?
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      else
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id != :currentId AND facebook_id NOT IN (#{networkIds})", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      end
    else
      if networkIds.nil?
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      else
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id NOT IN (#{networkIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      end
    end
    
    # puts bucket
    # puts recentIds
    
    opponentIndex = binarySearch(bucket, desiredScore, 0, bucket.length - 1)
    opponent = bucket[opponentIndex]
    
    # puts opponent
    
    return opponent
  end
  
  def match
    # Find an opponent for the user provided in params
    Rails.logger.info request.query_parameters.inspect
    
    user = User.find_by_facebook_id(params[:id])
    
    # puts user.score
    
    recentIds = '\''+params[:recents].split(',').join('\',\'')+'\''
    
    opponent = findOpponentForUser(user.score, params[:gender], params[:id], recentIds, nil)
    
    # puts opponent.facebook_id
    render :json => opponent.facebook_id
    # render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RAND()',:limit=>1,:include=>[:profile])[0]
  end 
  
  def friends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
    puts params
    
    friendIdArray = []
    
    currentUser = User.find_by_facebook_id(params[:id])
    
    # ActiveRecord::Base.execute("REPLACE INTO 'token' SET 'facebook_id' = ")
    token = Token.find_by_facebook_id(params[:id])
    if token.nil?
      token = Token.create({
        :facebook_id => params[:id],
        :access_token => params[:access_token]
      })
    else
      token.update_attribute('access_token', params[:access_token])
    end
    
    token.reload
    
    params[:_json].each{ |user|
      if User.find_by_facebook_id(user[:id].to_s).nil?
        user = User.create({
          :facebook_id => user[:id],
          :full_name => user[:name], 
          :gender => user[:gender],
          :score => 1500,
          :wins => 0,
          :losses => 0,
          :win_streak => 0,
          :loss_streak => 0
        })
        user.reload
        user.create_profile({
          :relationship_status => user[:relationship_status],
          :birthday => user[:birthday]
        })
      end
      
      # Insert friend into friendIdArray
      if not params[:id] == user[:id]
        friendIdArray << user[:id]
      end
    }
    
    # Generate first degree network for this user
    generateFirstDegreeNetworkForUser(params[:id], friendIdArray)
    generateSecondDegreeNetworkForUser(params[:id])
    
    # p friendIdArray
    
    render:text => {:success=>true}.to_json
  end
  
  def result
    # report a match result to the server 
    Rails.logger.info request.query_parameters.inspect
    
    winner = User.find_by_facebook_id(params[:w].to_s)
    loser  = User.find_by_facebook_id(params[:l].to_s)
    
    adjustScoresForUsers(winner, loser)
    
    render:text => {:success=>true}.to_json
  end

  def adjustScoresForUsers(winner, loser)
    winnerExpected = expectedOutcome(winner, loser)
    loserExpected = expectedOutcome(loser, winner)
    
    # Adjust the winner score
    winner.update_attributes(:wins => winner[:wins] + 1)
    winner.update_attributes(:win_streak => winner[:win_streak] + 1)
    winner.update_attributes(:loss_streak => 0)
    winner.update_attributes(:score => winner[:score] + (32 * (1 - winnerExpected)))
    
    # Adjust the loser score
    loser.update_attributes(:losses => loser[:losses] + 1)
    loser.update_attributes(:loss_streak => loser[:loss_streak] + 1)
    loser.update_attributes(:win_streak => 0)
    loser.update_attributes(:score => loser[:score] + (32 * (0 - loserExpected)))
  end
  
  def expectedOutcome(user, opponent)
    # Calculate the expected outcomes
    exponent = 10.0 ** ((opponent[:score] - user[:score]) / 400.0)
    expected = 1.0 / (1.0 + exponent)
    return expected
  end
     
  def binarySearch(array, value, low, high)
    if high < low
      return -1 # not found
    end
    
    mid = low + ((high - low) / 2).to_i
    
    if array[low].score == array[high].score
      puts rand(range_rand(low,high)).to_i
      return rand(range_rand(low,high)).to_i
    elsif array[mid].score > value
      return binarySearch(array, value, low, mid - 1)
    elsif array[mid].score < value
      return binarySearch(array, value, mid + 1, high)
    else
      return mid
    end
  end
  
  def range_rand(min,max)
    min + rand(max-min)
  end
  
  def calculateRange(score)
    # Pass in a desired score in which we want to find approximately 100~1000 people who are within +/- range
    # Calculate optimal +/- range based on SQL table stats assuming our scores are of normal distribution
    # We might have to perform a SQL table stats query every now and then to update the distribution
    # This will restrict the number of results that come back to optimize the binarySearch on the result set
  end

=begin
  Let's take these ratings as an example:
  Team A: 1500 points
  Team B: 1580 points


  Wikipedia's formula is:
  Expected Outcome = 1 / (1 + 10^((Enemy Rating - Your Rating)/400))
  New Rating = Current Rating + Maximum Possible Change * (Outcome - Expected Outcome)
  (Outcome is either 0 for a loss, 0.5 for a draw or 1 for a victory.)

  So this becomes:
  (note: I have found out that the windows calculator doesn't accept "^" for calculating the power. Instead, use an "y" if you want to do this via copy&paste. At least for the German version.)

  Team A:
  Expected Outcome:
  1/(1+10y((1580-1500)/400))= 0.387 [38.7% chance of winning]

  Loss:
  1500+32*(0-0.387)= 1487 [-13]

  Victory:
  1500+32*(1-0.387)= 1519 [+19]


  Team B:
  Expected Outcome:
  1/(1+10y((1500-1580)/400))= 0.613 [61.3% chance of winning]

  Loss:
  1580+32*(0-0.613)= 1560 [-20]

  Victory:
  1580+32*(1-0.613)= 1592 [+12]

=end

  def generateFirstDegreeNetworkForUser(facebookId, friendIdArray)
#    friendIdArray = ["1217270","1217767","1209924"]
    # This method generates a network link table of user -> friend with degree = 1
    puts "Generate 1st degree network link table for user with id: #{facebookId}"

    friendIdArray.each do |friendId|
      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => friendId }]).empty?
        network = Network.create({
          :facebook_id => facebookId,
          :friend_id => friendId, 
          :degree => 1
        })
        network.reload
      end
    end
    
    return nil
  end
  
  def generateSecondDegreeNetworkForUser(facebookId)
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
        network = Network.create({
          :facebook_id => facebookId,
          :friend_id => key, 
          :degree => value
        })
        network.reload
      end

    }

    # p secondHash

    return nil
  end
  
end
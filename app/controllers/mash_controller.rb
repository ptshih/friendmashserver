class MashController < ApplicationController
  def random
    # Find two random people who have similar scores
    Rails.logger.info request.query_parameters.inspect
    
    puts params[:recents].length
    
    # Randomly choose a user from the DB with a CSV of excluded IDs
    if params[:recents].length == 0
      recentIds = nil
      randomUser = User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
    else
      recentIds = '\''+params[:recents].split(',').join('","')+'\''
      randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id NOT IN (#{recentIds})",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
    end
    
    opponent = findOpponentForUser(randomUser.score, params[:gender], recentIds, randomUser.facebook_id)
    response = [randomUser.facebook_id, opponent.facebook_id]
    render :json => response
  end
  
  def findOpponentForUser(desiredScore, gender, recentIds = nil, currentId = nil)
    # First hit the DB with a CSV of excluded IDs and a match_score +/- match_range
    # Fetch an array of valid IDs from DB who match the +/- range from the current user's score
    # Perform a binary search on the array to find the best possible opponent
    # Return a single opponent
    
    range = 500
    
    if recentIds.nil?
      bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
    else
      bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
    end
    
    # puts bucket
    puts recentIds
    
    opponentIndex = binSearch(bucket, desiredScore)
    opponent = bucket[opponentIndex]
    
    # puts opponent
    
    return opponent
  end
  
  def match
    # Find an opponent for the user provided in params
    Rails.logger.info request.query_parameters.inspect
    
    user = User.find_by_facebook_id(params[:id])
    
    # puts user.score
    
    recentIds = '\''+params[:recents].split(',').join('","')+'\''
    
    opponent = findOpponentForUser(user.score, params[:gender], recentIds, params[:id])
    
    # puts opponent.facebook_id
    render :json => opponent.facebook_id
    # render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
  end 
  
  def friends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
    puts params
    currentUser = User.find_by_facebook_id(params[:id])
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
    }
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
  
  # If bSearch can't find an exact match, it'll return the closest neighbor based on score
  def bSearch(arr, elem, low, high)
    mid = low+((high-low)/2).to_i
    if low > high
      lowDiff = (elem - arr[low - 1].score).abs
      highDiff = (elem - arr[high].score).abs
      if lowDiff > highDiff
        return high
      else
        return low - 1
      end
    end
    if elem < arr[mid].score
      return bSearch(arr, elem, low, mid-1)
    elsif elem > arr[mid].score
      return bSearch(arr, elem, mid+1, high)
    else
      return mid
    end
  end

  def binSearch(a, x)
    return bSearch(a, x, 0, a.length - 1)
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
  
end
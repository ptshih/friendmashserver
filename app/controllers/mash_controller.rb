class MashController < ApplicationController
  def random
    # Randomly choose a user from the DB with a CSV of excluded IDs
    render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
  end
  
  def getMatchForUser
     render :json => User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>'RANDOM()',:limit=>1,:include=>[:profile])[0]
     
     # First hit the DB with a CSV of excluded IDs and a match_score +/- match_range
     # Now server has an array of valid IDs in memory that are +/- match_range
     # Now perform a binary search on the array around match_score to find the best possible opponent ID
     # return the single opponent ID to the client from the binary search results
  end 
  
  def postFriends
    # upload some users friends to save in the db
    Rails.logger.info request.query_parameters.inspect
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
  def adjustScoresForUsers(winner, loser)
=begin
  //calculate the expected outcomes
  double winnerExpected = this.expectedOutcome(winner, loser);
  double loserExpected = this.expectedOutcome(loser, winner);

  //adjust the winner score
  double winnerScore = winner.getScore()+(32*(1-winnerExpected));
  winner.setScore(winnerScore);
  winner.setWinStreak(winner.getWinStreak() + 1);
  winner.setWins(winner.getWins() + 1);
  winner.setLossStreak(new Long(0));

  //adjust the loser score
  double loserScore = loser.getScore()+(32*(0-loserExpected));
  loser.setScore(loserScore);
  loser.setLosses(loser.getLosses()+ 1);
  loser.setLossStreak(loser.getLossStreak() + 1);
  loser.setWinStreak(new Long(0));
=end
    @winnerExpected = expectedOutcome(winner, loser)
    @loserExpected = expectedOutcome(loser, winner)
    
    # Adjust the winner score
    winner.update_attributes(:wins => winner[:wins] + 1)
    winner.update_attributes(:win_streak => winner[:win_streak] + 1)
    winner.update_attributes(:loss_streak => 0)
    winner.update_attributes(:score => winner[:score] + (32 * (1 - @winnerExpected)))
    
    # Adjust the loser score
    loser.update_attributes(:losses => loser[:losses] + 1)
    loser.update_attributes(:loss_streak => loser[:loss_streak] + 1)
    loser.update_attributes(:win_streak => 0)
    loser.update_attributes(:score => loser[:score] - (32 * (0 - @loserExpected)))
  end
  
  def expectedOutcome(user, opponent)
    # Calculate the expected outcomes
    @exponent = 10 ** ((opponent[:score] - user[:score]) / 400)
    @expected = 1 / (1 + @exponent)
    return @expected
  end
end
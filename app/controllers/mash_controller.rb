# Achievement icon/badges go into profile page
# special rankings, maybe chevrons, wow pvp ranking badges
# win streak crown
# location based: mayor of location

# CREATING INDEX
# ActiveRecord::Base.connection.execute("create unique index idx_users_facebook_id on users (facebook_id)")
# ActiveRecord::Base.connection.execute("create index idx_networks_facebook_id on networks (facebook_id)")
# ActiveRecord::Base.connection.execute("create index idx_networks_friend_id on networks (friend_id)")
# ActiveRecord::Base.connection.execute("create unique index idx_profiles_facebook_id on profiles (facebook_id)")

class MashController < ApplicationController
  require 'process_friends'
  require 'generate_result'
  
  def random
    # Find two random people who have similar scores
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # puts params[:recents].length
    
    # params[:mode]
    # 0 - ALL
    # 1 - NETWORK
    
    if params[:mode] == "0"
      networkIds = nil
    else
      networkIds = []
      Network.where("facebook_id = '#{params[:id]}'").each do |network|
        networkIds << network.friend_id
      end
      # p networkIds
      if networkIds.empty?
        networkIds = nil
      else
        networkIds = '\'' + networkIds.split(',').join('\',\'')+'\'' 
      end
    end
    
    # MySQL uses RAND, SQLLite uses RANDOM
    # Apparently MySQL-RDS has to use RAND() but PostgreSQL and SQLite use RANDOM()
    if Rails.env == "production"
      randQuery = 'RAND()'
    else
      randQuery = 'RANDOM()'
    end
    
    # Randomly choose a user from the DB with a CSV of excluded IDs
    if params[:recents].length == 0
      recentIds = nil
      if networkIds.nil?
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id != '#{params[:id]}'",:order=>randQuery,:limit=>1)[0]
      else
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id != '#{params[:id]}' AND facebook_id IN (#{networkIds})",:order=>randQuery,:limit=>1)[0]
      end
    else
      recentIds = '\'' + params[:recents].split(',').join('\',\'')+'\'' 
      if networkIds.nil?
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id != '#{params[:id]}' AND facebook_id NOT IN (#{recentIds})",:order=>randQuery,:limit=>1)[0]
      else
        randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id != '#{params[:id]}' AND facebook_id NOT IN (#{recentIds}) AND facebook_id IN (#{networkIds})",:order=>randQuery,:limit=>1)[0]
      end
    end
    
    # randomUser = User.first
    # puts "LOL"
    # p randomUser
    if not randomUser.nil?
      if params[:mode] == "0"
        opponent = find_opponent(randomUser.score, params[:gender], randomUser.facebook_id, recentIds, networkIds)
      else
        opponent = find_opponent(randomUser.score_network, params[:gender], randomUser.facebook_id, recentIds, networkIds)
      end
      
      if not opponent.nil?
        response = [randomUser.facebook_id, opponent.facebook_id]

        respond_to do |format|
          format.xml  { render :xml => response }
          format.json  { render :json => response }
        end
      else
        response = {:error => "second opponent not found"} # did not find an opponent
        respond_to do |format|
          format.xml  { render :xml => response, :status => :not_implemented }
          format.json  { render :json => response, :status => :not_implemented }
        end
      end
    else
      # ran out of opponents!!!
      response = {:error => "first opponent not found"}
      respond_to do |format|
        format.xml  { render :xml => response, :status => :not_implemented }
        format.json  { render :json => response, :status => :not_implemented }
      end
    end
  end
  
  def find_opponent(desiredScore, gender, currentId = nil, recentIds = nil, networkIds = nil)
    # First hit the DB with a CSV of excluded IDs and a match_score +/- match_range
    # Fetch an array of valid IDs from DB who match the +/- range from the current user's score
    # Perform a binary search on the array to find the best possible opponent
    # Return a single opponent
    
    # OLD RANGE CALC FORMULA
    # scoreRange = calculate_range(desiredScore)
    # low = scoreRange[0]
    # high = scoreRange[1]
    
    # USE NEW DYNAMIC RANGE CALC
    # def calculate_bounds(userScore, pop, popAverage, popSD, sampleSize)
    # userScore = score used to find range
    # pop = total population
    # popAverage = average score of total population
    # popSD = standard deviation of total population scores
    # sampleSize = how many results we want inside our bounds
    
    # We need to calculate POP, POPAVERAGE, and POPSD from the DB, not everytime
    # Probably calculate it once a day/hour/etc... and store it in a static table/cache
    
    # for now lets calculate the count on every request
    # female = 903
    # male = 1420
    
    
    
    bounds = calculate_bounds(desiredScore, 900.0, 1500.0, 282.0, 500.0)
    low = bounds[0]
    high = bounds[1]
    
    if Rails.env == "production"
      randQuery = 'RAND()'
    else
      randQuery = 'RANDOM()'
    end
    
    if recentIds.nil?
      if networkIds.nil?
        bucket = User.all(:conditions=>"score > #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id != '#{currentId}'",:order=>randQuery,:select =>"facebook_id",:limit=>1)
        # bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }], :order => randQuery).select("facebook_id, score")
      else
        bucket = User.all(:conditions=>"score_network > #{low} AND score_network <= #{high} AND gender = '#{gender}' AND facebook_id IN (#{networkIds}) AND facebook_id != '#{currentId}'",:order=>randQuery,:select =>"facebook_id",:limit=>1)
        # bucket = User.where(["score_network >= :lowScore AND score_network <= :highScore AND gender = :gender AND facebook_id != :currentId AND facebook_id IN (#{networkIds})", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score_network")
      end
    else
      if networkIds.nil?
        bucket = User.all(:conditions=>"score > #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id NOT IN (#{recentIds}) AND facebook_id != '#{currentId}'",:order=>randQuery,:select =>"facebook_id",:limit=>1)
        # bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      else
        bucket = User.all(:conditions=>"score_network > #{low} AND score_network <= #{high} AND gender = '#{gender}' AND facebook_id NOT IN (#{recentIds}) AND facebook_id IN (#{networkIds}) AND facebook_id != '#{currentId}'",:order=>randQuery,:select =>"facebook_id",:limit=>1)
        # bucket = User.where(["score_network >= :lowScore AND score_network <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id IN (#{networkIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score_network")
      end
    end
  
    return bucket[0]
  end
  
  def match
    # Find an opponent for the user provided in params
    # CURRENTLY UNUSED, GAME MODE DISABLED
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    user = User.find_by_facebook_id(params[:id])
    
    # puts user.score
    
    recentIds = '\''+params[:recents].split(',').join('\',\'')+'\''
    
    opponent = find_opponent(user.score, params[:gender], params[:id], recentIds, nil)
    
    # puts opponent.facebook_id
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => opponent.facebook_id }
      format.json  { render :json => opponent.facebook_id }
    end
  end 
  
  def token
    # Rails.logger.info request.query_parameters.inspect
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # Store the user's access token
    token = Token.find_by_facebook_id(params["id"])
    if token.nil?
      token = Token.create(
        :facebook_id => params["id"],
        :access_token => params["access_token"],
        :udid => request.env["HTTP_X_UDID"]
      )
    else
      # token.update_attribute('access_token', params[:access_token])
      token.update_attributes(
        :access_token => params["access_token"],
        :udid => request.env["HTTP_X_UDID"]
      )
    end
    
    user = User.find_by_facebook_id(params["id"])
    if user.nil?
      # create a record for the current user
      newUser = User.create(
        :facebook_id => params["id"],
        :gender => params["gender"],
        :score => 1500,
        :score_network => 1500,
        :wins => 0,
        :wins_network => 0,
        :losses => 0,
        :losses_network => 0,
        :win_streak => 0,
        :win_streak_network => 0,
        :loss_streak => 0,
        :loss_streak_network => 0,
        :win_streak_max => 0,
        :loss_streak_max => 0,
        :win_streak_max_network => 0,
        :loss_streak_max_network => 0
      )
      newProfile = Profile.create(
        :facebook_id => params["id"],
        :first_name => params["first_name"].nil? ? nil : params["first_name"],
        :last_name => params["last_name"].nil? ? nil : params["last_name"],
        :full_name => params["name"].nil? ? nil : params["name"],
        :votes => 0,
        :votes_network => 0
      )
      user = newUser
    else
      user.update_attributes(
        :gender => params["gender"]
      )
    end
    
    # Process friends in worker
    Delayed::Job.enqueue ProcessFriends.new(params["id"])
    
=begin
# CANNOT get list of friends of friends, damnit facebook
{
   "error": {
      "type": "OAuthException",
      "message": "(#604) Can't lookup all friends of 222383. Can only lookup for the logged in user (548430564), or friends of the logged in user with the appropriate permission"
   }
}

# Now get the user's second degree friends
secondDegreeFriends = Array.new

firstDegreeFriends.each do |firstDegreeFriend|
  firstDegreeUser = User.find_by_facebook_id(firstDegreeFriend["id"])
  secondDegreeFriends = secondDegreeFriends + firstDegreeUser.friends(fields)
end

# insert the second degree friends into the DB as degree 2
# process_friends(params[:id], secondDegreeFriends, 2)
=end
    
    
    # Fire off a FBConnect friends request using the user's token
    #
    # Insert the results into the DB
    # get_fb_friends(params[:id], token[:access_token])
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
  
  # Tell the server to process the current user's friends
  def friends
    
    # deprecated
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
  

  
  def result
    # report a match result to the server 
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # puts request.env["HTTP_X_USER_ID"]
    # puts request.env["HTTP_X_UDID"]
    
    # Increment vote count for current user
    # increment_counter
    Profile.increment_counter('votes',Profile.find_by_facebook_id(params[:id]).id)
    if params[:mode] == "1"
      Profile.increment_counter('votes_network',Profile.find_by_facebook_id(params[:id]).id)
    end
    
    winner = User.find_by_facebook_id(params[:w])
    loser  = User.find_by_facebook_id(params[:l])
    
    winnerBeforeScore = winner[:score]
    loserBeforeScore = loser[:score]
    
    adjustScoresForUsers(winner, loser, params[:mode])
    
    # Insert a NEW record into Result table to keep track of the fight
    # If left is true, that means left side was DISCARDED
    Delayed::Job.enqueue GenerateResult.new(params[:id], params[:w], params[:l], params[:left], params[:mode], winnerBeforeScore, loserBeforeScore)
    
    # Result.create(
    #   :facebook_id => params[:id],
    #   :winner_id => params[:w],
    #   :loser_id => params[:l],
    #   :left => params[:left],
    #   :mode => params[:mode],
    #   :winner_score => winner[:score],
    #   :loser_score => loser[:score]
    # )
    
    # Result.new do |r|
    #   r.facebook_id = params[:id]
    #   r.winner_id = params[:w]
    #   r.loser_id = params[:l]
    #   r.left = params[:left]
    #   r.mode = params[:mode]
    #   r.winner_score = winner[:score]
    #   r.loser_score = loser[:score]
    #   r.save
    # end
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
  
  def profile
    # given a parameter facebookId
    # return a hash of a given user's profile
    
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    profile = User.select('*').where('facebook_id' => params[:id]).joins(:profile).first
    
    # WORKS BUT NOT PERFORMANT!!! VERY SLOW
    #
    ranksHash = ActiveRecord::Base.connection.execute("select sum(case when a.score>b.score then 1 else 0 end) as rankoftotal, sum(case when a.score>b.score AND c.friend_id is not null then 1 else 0 end) as rankofnetwork, sum(case when c.friend_id is not null then 1 else 0 end) as networktotal, count(*) as total from users a left join users b on 1=1 and b.facebook_id='#{profile['facebook_id']}' left join networks c on c.friend_id = a.facebook_id and c.facebook_id=b.facebook_id where a.gender = b.gender")[0]
    profile['rank'] = ranksHash['rankoftotal'].to_i
    profile['rank_network'] = ranksHash['rankofnetwork'].to_i
    profile['total'] = ranksHash['total'].to_i
    profile['total_network'] = ranksHash['networktotal'].to_i
    # ActiveRecord::Base.connection.execute("select sum(case when a.score>c.score then 1 else 0 end) as rankOfTotal,sum(case when a.score>c.score && b.id!=null then 1 else 0 end) as rankAmongFriends,sum(1) as totalCount,sum(case when b.id!=null then 1 else 0 end) as networkCount from users a left outer join networks b on a.facebook_id=b.friend_id left outer join users c where c.id='#{profile['facebook_id']}' and a.gender=c.gender")
    
    # profile['rank'] = ActiveRecord::Base.connection.execute("SELECT count(*) from Users where score > #{profile['score']} AND gender = '#{profile['gender']}'")[0][0].to_i + 1
    # profile['rank_network'] = 0;
    # profile['total'] = User.count(:conditions=>"gender = '#{profile['gender']}'").to_i
    # profile['total_network'] = profile['total']
        
    profile['votes'] = profile['votes'].to_i
    profile['votes_network'] = profile['votes_network'].to_i
    
    # send response
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => profile }
      format.json  { render :json => profile }
    end
  end
  
  def topplayers
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    if params[:count].nil?
      count = 99
    else
      count = params[:count]
    end
    
    topPlayers = Profile.all(:conditions=>"votes > 0",:order=>"votes desc",:limit=>99)
    
    rankings = []
    
    topPlayers.each_with_index do |profile,rank|
      rankingsHash = {
        :facebook_id => profile[:facebook_id],
        :full_name => profile[:full_name],
        :first_name => profile[:first_name],
        :last_name => profile[:last_name],
        :votes => profile[:votes],
        :votes_network => profile[:votes_network],
        :rank => rank + 1
      }
      rankings << rankingsHash
    end
    
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => rankings }
      format.json  { render :json => rankings }
    end
    
  end
  
  def rankings
    # return a list of top 25 in each category
    # expects parameters
    # gender
    # mode (all,network)
    
    Rails.logger.info request.query_parameters.inspect
    # Rails.logger.info request.env.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    if params[:count].nil?
      count = 99
    else
      count = params[:count]
    end
    
    if params[:mode] == "0"
      networkIds = nil
    else
      networkIds = []
      Network.where("facebook_id = '#{params[:id]}'").each do |network|
        networkIds << network.friend_id
      end
      # p networkIds
      if networkIds.empty?
        networkIds = nil
      else
        networkIds = '\'' + networkIds.split(',').join('\',\'')+'\'' 
      end
    end
    
    # Active Record Join Alternative
    # users = User.select('*').all(:conditions=>"gender = '#{params[:gender]}'",:order=>"score desc",:limit=>count,:joins=>:profile)
    if networkIds.nil?
      users = User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>"score desc",:limit=>count,:include=>:profile)
    else
      users = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id IN (#{networkIds})",:order=>"score_network desc",:limit=>count,:include=>:profile)
    end
    
    rankings = []
    
    users.each_with_index do |user,rank|
      if params[:mode] == "0"
        actualScore = user[:score]
        actualWins = user[:wins]
        actualLosses = user[:losses]
        actualWinStreak = user[:win_streak]
        actualLossStreak = user[:loss_streak]
        actualWinStreakMax = user[:win_streak_max]
        actualLossStreakMax = user[:loss_streak_max]
      else
        actualScore = user[:score_network]
        actualWins = user[:wins_network]
        actualLosses = user[:losses_network]
        actualWinStreak = user[:win_streak_network]
        actualLossStreak = user[:loss_streak_network]
        actualWinStreakMax = user[:win_streak_max_network]
        actualLossStreakMax = user[:loss_streak_max_network]
      end
      rankingsHash = {
        :facebook_id => user[:facebook_id],
        :full_name => user.profile[:full_name],
        :first_name => user.profile[:first_name],
        :last_name => user.profile[:last_name],
        :score => actualScore,
        :wins => actualWins,
        :losses => actualLosses,
        :win_streak => actualWinStreak,
        :loss_streak => actualLossStreak,
        :win_streak_max => actualWinStreakMax,
        :loss_streak_max => actualLossStreakMax,
        :rank => rank + 1
      }
      rankings << rankingsHash
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => rankings }
      format.json  { render :json => rankings }
    end
  end
  
  # Calculations

  def adjustScoresForUsers(winner, loser, mode = 0)
    winnerExpected = expected_outcome(winner, loser, mode)
    loserExpected = expected_outcome(loser, winner, mode)
    
    if mode == "0"
      # Adjust the winner score
      winner.update_attributes(
        :wins => winner[:wins] + 1,
        :win_streak => winner[:win_streak] + 1,
        :loss_streak => 0,
        :score => winner[:score] + (32 * (1 - winnerExpected)),
        :win_streak_max => winner[:win_streak] > winner[:win_streak_max] ? winner[:win_streak] : winner[:win_streak_max]
      )
      
      # winner.update_attributes(:wins => winner[:wins] + 1)
      # winner.update_attributes(:win_streak => winner[:win_streak] + 1)
      # winner.update_attributes(:loss_streak => 0)
      # winner.update_attributes(:score => winner[:score] + (32 * (1 - winnerExpected)))
      
      # if winner[:win_streak] > winner[:win_streak_max]
      #   winner.update_attributes(:win_streak_max => winner[:win_streak])
      # end

      # Adjust the loser score
      loser.update_attributes(
        :losses => loser[:losses] + 1,
        :loss_streak => loser[:loss_streak] + 1,
        :win_streak => 0,
        :score => loser[:score] + (32 * (0 - loserExpected)),
        :loss_streak_max => loser[:loss_streak] > loser[:loss_streak_max] ? loser[:loss_streak] : loser[:loss_streak_max]
      )
      
      # loser.update_attributes(:losses => loser[:losses] + 1)
      # loser.update_attributes(:loss_streak => loser[:loss_streak] + 1)
      # loser.update_attributes(:win_streak => 0)
      # loser.update_attributes(:score => loser[:score] + (32 * (0 - loserExpected)))
      # 
      # if loser[:loss_streak] > loser[:loss_streak_max]
      #   loser.update_attributes(:loss_streak_max => loser[:loss_streak])
      # end
    else
      # Adjust the winner score
      winner.update_attributes(
        :wins_network => winner[:wins_network] + 1,
        :win_streak_network => winner[:win_streak_network] + 1,
        :loss_streak_network => 0,
        :score_network => winner[:score_network] + (32 * (1 - winnerExpected)),
        :win_streak_max_network => winner[:win_streak_network] > winner[:win_streak_max_network] ? winner[:win_streak_network] : winner[:win_streak_max_network]
      )
      
      # winner.update_attributes(:wins_network => winner[:wins_network] + 1)
      # winner.update_attributes(:win_streak_network => winner[:win_streak_network] + 1)
      # winner.update_attributes(:loss_streak_network => 0)
      # winner.update_attributes(:score_network => winner[:score_network] + (32 * (1 - winnerExpected)))
      # 
      # if winner[:win_streak_network] > winner[:win_streak_max_network]
      #   winner.update_attributes(:win_streak_max_network => winner[:win_streak_network])
      # end

      # Adjust the loser score
      loser.update_attributes(
        :losses_network => loser[:losses_network] + 1,
        :loss_streak_network => loser[:loss_streak_network] + 1,
        :win_streak_network => 0,
        :score_network => loser[:score_network] + (32 * (0 - loserExpected)),
        :loss_streak_max_network => loser[:loss_streak_network] > loser[:loss_streak_max_network] ? loser[:loss_streak_network] : loser[:loss_streak_max_network]
      )
      
      # loser.update_attributes(:losses_network => loser[:losses_network] + 1)
      # loser.update_attributes(:loss_streak_network => loser[:loss_streak_network] + 1)
      # loser.update_attributes(:win_streak_network => 0)
      # loser.update_attributes(:score_network => loser[:score_network] + (32 * (0 - loserExpected)))
      # 
      # if loser[:loss_streak_network] > loser[:loss_streak_max_network]
      #   loser.update_attributes(:loss_streak_max_network => loser[:loss_streak_network])
      # end
    end
  end
  
  def expected_outcome(user, opponent, mode = 0)
    if mode == "0"
      user_score = user[:score]
      opponent_score = opponent[:score]
    else
      user_score = user[:score_network]
      opponent_score = opponent[:score_network]
    end
    
    # Calculate the expected outcomes
    exponent = 10.0 ** ((opponent_score - user_score) / 400.0)
    expected = 1.0 / (1.0 + exponent)
    return expected
  end
  
  def calculate_range(score)
    # DEPRECATED
    # SEE calculate_bounds
    
    # Pass in a desired score
    # We break up the buckets into 10 ranges
    # Based on the score, we then return the desired range back to the SQL query
    
    # Elo Range
    # 600 <-> 2400
    # 0 ~ 3000 (absolute min/max)    
    
    ranges = [0, 1145, 1263, 1352, 1429, 1500, 1571, 1648, 1735, 1855, 3000]
    found = 0
    low = 0
    high = 10
    
    ranges.each_with_index do |r,i|
      if score > r
        next # keep going
      else
        found = 1
        low = i - 1
        high = i
        break if found == 1
      end
    end
    

    scoreRange = [ranges[low],ranges[high]]
    p scoreRange
    return scoreRange
  end
  
  def calculate_bounds(userScore, pop, popAverage, popSD, sampleSize)
    # returns an array [low, high]
    
    k_low = (-1 * (sampleSize / pop))
    k_high = (1 * (sampleSize / pop))

    array_returns_low = (600..userScore).map { |i|
      (k_low + Math.erf((userScore-popAverage)/(popSD*(2.0**0.5))) - Math.erf((i-popAverage)/(popSD*(2.0**0.5)))).abs
    }

    array_returns_high = (userScore..2400).map { |i|
      (k_high + Math.erf((userScore-popAverage)/(popSD*(2.0**0.5))) - Math.erf((i-popAverage)/(popSD*(2.0**0.5)))).abs
    }

    return [(600..userScore).map[array_returns_low.index(array_returns_low.min)], (userScore..2400).map[array_returns_high.index(array_returns_high.min)]]
  end
  
  # takes a gzipped string and deflates it
  def inflate(string)
    zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    buf = zstream.inflate(string)
    zstream.finish
    zstream.close
    buf
  end
  
end
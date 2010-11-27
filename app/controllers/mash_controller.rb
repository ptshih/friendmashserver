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
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # params[:mode]
    # 0 - ALL
    # 1 - NETWORK
    
    networkIds = []
    if params[:mode] == "1"
      Network.where("facebook_id = '#{params[:id]}'").each do |network|
        networkIds << network.friend_id
      end
      networkString = "'" + networkIds.join('\',\'') + "'"
    end
    
    # MySQL uses RAND, SQLLite uses RANDOM
    # Apparently MySQL-RDS has to use RAND() but PostgreSQL and SQLite use RANDOM()
    if Rails.env == "production" || Rails.env == "staging"
      randQuery = 'RAND()'
    else
      randQuery = 'RANDOM()'
    end
    
    excludedIds = params[:recents].split(',') # split on comma
    
    excludedIds << "#{params[:id]}" # add currentId to excludedIds
    
    excludedString = "'" + excludedIds.join('\',\'') + "'" # SQL string for excludedIds
    
    # "'" + arr.join('\',\'') + "'"
    
    # Randomly choose a user from the DB with a CSV of excluded IDs
    if networkIds.empty?
      randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id NOT IN (#{excludedString})",:order=>randQuery,:limit=>1)[0]
    else
      randomUser = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id NOT IN (#{excludedString}) AND facebook_id IN (#{networkString})",:order=>randQuery,:limit=>1)[0]
    end
    
    excludedIds << "#{randomUser.facebook_id}" # add the random user into the excludedIds array
    
    if not randomUser.nil?
      opponent = find_opponent(randomUser.score, params[:gender], excludedIds, networkIds)
      
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
  
  def find_opponent(desiredScore, gender, excludedIds = [], networkIds = [])
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
    
    if Rails.env == "production" || Rails.env == "staging"
      randQuery = 'RAND()'
    else
      randQuery = 'RANDOM()'
    end
    
    excludedString = "'" + excludedIds.join('\',\'') + "'" # SQL string for excludedIds
    
    if networkIds.empty?
      opponent = User.all(:conditions=>"score > #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id NOT IN (#{excludedString})",:order=>randQuery,:select =>"facebook_id",:limit=>1)
    else
      networkString = "'" + networkIds.join('\',\'') + "'"
      opponent = User.all(:conditions=>"score > #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id NOT IN (#{excludedString}) AND facebook_id IN (#{networkString})",:order=>randQuery,:select =>"facebook_id",:limit=>1)
    end
  
    return opponent.first
  end
  
  def match
    # Find an opponent for the user provided in params
    # CURRENTLY UNUSED, GAME MODE DISABLED
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end

    response = {:error => "api not implemented"}
    respond_to do |format|
      format.xml  { render :xml => response, :status => :not_implemented }
      format.json  { render :json => response, :status => :not_implemented }
    end
  end 
  
  def token
    # Rails.logger.info request.query_parameters.inspect
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
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
    
    respond_to do |format|
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
    
  def result
    # report a match result to the server 
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
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
    
    respond_to do |format|
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
    
    query = "select sum(case when a.score>b.score then 1 else 0 end) as rankoftotal, sum(case when a.score>b.score AND c.friend_id is not null then 1 else 0 end) as rankofnetwork, sum(case when c.friend_id is not null then 1 else 0 end) as networktotal, count(*) as total from users a left join users b on 1=1 and b.facebook_id='#{profile['facebook_id']}' left join networks c on c.friend_id = a.facebook_id and c.facebook_id=b.facebook_id where a.gender = b.gender"
    
    if Rails.env == "production" || Rails.env == "staging"
      ranksHash = ActiveRecord::Base.connection.execute(query).fetch_hash
    else
      ranksHash = ActiveRecord::Base.connection.execute(query)[0]
    end
    
    profile['rank'] = ranksHash['rankoftotal'].to_i + 1
    profile['rank_network'] = ranksHash['rankofnetwork'].to_i + 1
    profile['total'] = ranksHash['total'].to_i
    profile['total_network'] = ranksHash['networktotal'].to_i + 1 # need to add 1 for the current user since networks doesnt do a user -> user entry
    profile['votes'] = profile['votes'].to_i
    profile['votes_network'] = profile['votes_network'].to_i
    
    # ActiveRecord::Base.connection.execute("select sum(case when a.score>c.score then 1 else 0 end) as rankOfTotal,sum(case when a.score>c.score && b.id!=null then 1 else 0 end) as rankAmongFriends,sum(1) as totalCount,sum(case when b.id!=null then 1 else 0 end) as networkCount from users a left outer join networks b on a.facebook_id=b.friend_id left outer join users c where c.id='#{profile['facebook_id']}' and a.gender=c.gender")
    
    # profile['rank'] = ActiveRecord::Base.connection.execute("SELECT count(*) from Users where score > #{profile['score']} AND gender = '#{profile['gender']}'")[0][0].to_i + 1
    # profile['rank_network'] = 0;
    # profile['total'] = User.count(:conditions=>"gender = '#{profile['gender']}'").to_i
    # profile['total_network'] = profile['total']
    
    # send response
    respond_to do |format|
      format.xml  { render :xml => profile }
      format.json  { render :json => profile }
    end
  end
  
  def topplayers
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
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
      format.xml  { render :xml => rankings }
      format.json  { render :json => rankings }
    end
  end
  
  # Calculations

  def adjustScoresForUsers(winner, loser, mode = "0")
    winnerExpected = expected_outcome(winner, loser)
    loserExpected = expected_outcome(loser, winner)
    
    # Adjust the winner score
    winner.update_attributes(
      :wins => (mode == "0") ? winner[:wins] + 1 : winner[:wins],
      :wins_network => (mode == "1") ? winner[:wins_network] + 1 : winner[:wins_network],
      :win_streak => (mode == "0") ? winner[:win_streak] + 1 : winner[:win_streak],
      :win_streak_network => (mode == "1")? winner[:win_streak_network] + 1 : winner[:win_streak_network],
      :loss_streak => (mode == "0") ? 0 : winner[:loss_streak],
      :loss_streak_network => (mode == "1") ? 0 : winner[:loss_streak_network],
      :score => winner[:score] + (32 * (1 - winnerExpected)),
      :win_streak_max => (mode == "0") ? ( winner[:win_streak] + 1 > winner[:win_streak_max] ? winner[:win_streak] + 1: winner[:win_streak_max] ) : winner[:win_streak_max],
      :win_streak_max_network => (mode == "1") ? ( winner[:win_streak_network] + 1 > winner[:win_streak_max_network] ? winner[:win_streak_network] + 1 : winner[:win_streak_max_network] ) : winner[:win_streak_max_network]
    )
    
    # Adjust the loser score
    loser.update_attributes(
      :losses => (mode == "0") ? loser[:losses] + 1 : loser[:losses],
      :losses_network => (mode == "1") ? loser[:losses_network] + 1 : loser[:losses_network],
      :loss_streak => (mode == "0") ? loser[:loss_streak] + 1 : loser[:loss_streak],
      :loss_streak_network => (mode == "1") ? loser[:loss_streak_network] + 1 : loser[:loss_streak_network],
      :win_streak => (mode == "0") ? 0 : loser[:win_streak],
      :win_streak_network => (mode == "1") ? 0 : loser[:win_streak_network],
      :score => loser[:score] + (32 * (0 - loserExpected)),
      :loss_streak_max => (mode == "0") ? ( loser[:loss_streak] + 1 > loser[:loss_streak_max] ? loser[:loss_streak] + 1 : loser[:loss_streak_max] ) : loser[:loss_streak_max],
      :loss_streak_max_network => (mode == "1") ? ( loser[:loss_streak_network]  + 1 > loser[:loss_streak_max_network] ? loser[:loss_streak_network] + 1 : loser[:loss_streak_max_network] ) : loser[:loss_streak_max_network]
    )
    
    return
  end
  
  def expected_outcome(user, opponent)    
    # Calculate the expected outcomes
    exponent = 10.0 ** ((opponent[:score] - user[:score]) / 400.0)
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
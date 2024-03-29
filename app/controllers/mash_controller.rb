class MashController < ApplicationController
  require 'process_friends'
  require 'generate_result'
  require 'dalli'
  require 'update_statistic_summary'
  
  #
  # APIs for Client
  #
  
  def random
    # This API will randomly choose a single user from the database
    # It will then call find_opponent to find an opponent close to this user's score
    # The return will be a JSON string of 2 facebookIds for left and right
    # params[:mode]
    # 0 - ALL
    # 1 - NETWORK
    
    
    
    # LOGGING TO DATABASE
    logging(request, "random", params[:mode].to_i)
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    networkIds = []
    
    if params[:mode].to_i == 1
      # dc = Dalli::Client.new('127.0.0.1:11211',{:expires_in=>300.seconds})
      # networkString = dc.get("#{params[:id].to_i}")
      networkString =  nil
      
      if networkString.nil?
        Network.where("facebook_id = #{params[:id].to_i}").each do |network|
          networkIds << network.friend_id
        end
      end
      # dc.set("#{params[:id].to_i}",networkString,300)
      
    elsif params[:mode].to_i == 2
      networkIds = network_cache(params[:id].to_i)
    elsif params[:mode].to_i == 3
      networkIds = classmate_cache(params[:id].to_i)
    end
    
    # MySQL uses RAND, SQLLite uses RANDOM
    # Apparently MySQL-RDS has to use RAND() but PostgreSQL and SQLite use RANDOM()
    # if Rails.env == "production" || Rails.env == "staging"
    #   randQuery = 'RAND()'
    # else
    #   randQuery = 'RANDOM()'
    # end
    randQuery = 'RAND()'
    
    # Handle excluded recent IDs
    excludedIds = params[:recents].split(',') # split on comma
    excludedIds << "#{params[:id].to_i}" # add currentId to excludedIds
    excludedIds = excludedIds.map do |ex| ex.to_i end # convert excludedIds array to store integers instead of strings

    # perform score bias; too many unranked profiles, don't care about terrible profile pics for now
    lowerBound = rand(100) + 1400 # random between 1200 and 1500
    
    # NOTE:
    # only do in Everyone Mode!!!
    if params[:mode].to_i == 0
      # perform score bias to retain users (a/b testing at the moment, token.id odd enables biasing)
      #       condition 1: if user has less than 10 votes outside of their network, show biased+ mash
      #       condition 2: every time recent mashes is empty, show a biased+ mash
      # playerToken = Token.all(:conditions=>"facebook_id= #{params[:id]}", :select =>"id", :limit=>1).first
      #       playerProfile = Profile.all(:conditions=>"facebook_id= #{params[:id]} AND votes - votes_network < 10").first
      #       if (playerToken.id%2 > 0) && ( (params[:recents].empty?) || !(playerProfile.nil?))
      #         lowerBound=1600
      #       end
      # perform bias; first 3 mashes; then every 3rd; notice that every mash adds 2 to excluded and also 1 for player id
      if excludedIds.length%3==1 || excludedIds.length<10
        lowerBound=1600
      end
      
    end
  
    # Randomly choose a user from the DB with a CSV of excluded IDs
    if networkIds.empty?
      excludedString = excludedIds.join(',') # SQL string for excludedIds
      randomUser = User.all(:conditions=>"score >= #{lowerBound} AND gender = '#{params[:gender]}' AND facebook_id NOT IN (#{excludedString})",:order=>randQuery,:select =>"facebook_id, score",:limit=>1).first
    else
      networkIds = networkIds.map do |ex| ex.to_i end # convert excludedIds array to store integers instead of strings
        
      # If we are in network mode, instead of passing both excluded and IN network, we do an array diff
      # So that we only have to pass an IN network array which is IN - EXCLUDED
      networkIds = networkIds - excludedIds
      
      # puts "networks: #{networkIds.inspect}"
      # puts "excluded: #{excludedIds.inspect}"
      # puts "count: #{networkIds.count}"
      # if somehow we ended up with no networkIds after exclusion
      if networkIds.empty?
        randomUser = nil
      else
        networkString = networkIds.join(',')
        randomUser = User.all(:conditions=>"score >= #{lowerBound} AND gender = '#{params[:gender]}' AND facebook_id IN (#{networkString})",:order=>randQuery,:select =>"facebook_id, score",:limit=>1).first
      end
    end
    
    if not randomUser.nil?
      excludedIds << randomUser.facebook_id # add the random user into the excludedIds array
      
      if params[:mode].to_i > 0
        networkIds = networkIds - excludedIds
      end

      # Previous way was just to use the user's score
       opponent = find_opponent(randomUser.score, params[:gender], excludedIds, networkIds, params[:id].to_i, params[:mode].to_i)
      
      # Now to use the last opponent's score as a measure
      # Find an opponent for the randomly selected user; lost to last opponent than take lower score, won take higher
      # if randomUser.win_streak>0
      #   opponentScoreToMatch = randomUser.last_opponent_score+50
      # else
      #   opponentScoreToMatch = randomUser.last_opponent_score-50
      # end
      # opponent = find_opponent(opponentScoreToMatch, params[:gender], excludedIds, networkIds)
      
      if not opponent.nil?
        # 50/50 chance for left/right position
        if rand(2).zero?
          response = [randomUser.facebook_id.to_s, opponent.facebook_id.to_s]
        else
          response = [opponent.facebook_id.to_s, randomUser.facebook_id.to_s]
        end
        respond_to do |format|
          format.xml  { render :xml => response }
          format.json  { render :json => response }
        end
      else
        # did not find an opponent
        puts "Error: Second opponent not found"
        response = {:error => "second opponent not found"}
        respond_to do |format|
          format.xml  { render :xml => response, :status => :not_implemented }
          format.json  { render :json => response, :status => :not_implemented }
        end
      end
    else
      # ran out of opponents!!!
      puts "Error: First opponent not found"
      response = {:error => "first opponent not found"}
      respond_to do |format|
        format.xml  { render :xml => response, :status => :not_implemented }
        format.json  { render :json => response, :status => :not_implemented }
      end
    end
  end
  
  def match
    # Find an opponent for the user provided in params
    # CURRENTLY UNUSED, GAME MODE DISABLED
    Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
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
    # This API is called when a user signs in to facebook
    # This will create/update a record in the Tokens table for the user
    # It will create/update a record in the Users table for the current user
    # Then it will call a delayed job to process the user's friends list
    
    # Rails.logger.info request.query_parameters.inspect
    
    # LOGGING TO DATABASE
    logging(request, "token")
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # Store the user's access token
    token = Token.find_by_facebook_id(params["id"].to_i)
    if token.nil?
      token = Token.create(
        :facebook_id => params["id"].to_i,
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
    
    # Process current user
    ProcessFriends.new.create_user(params)
    
    # Process friends of the current user in a delayed job
    ProcessFriends.new(params["id"].to_i).perform # do it synchronously
    
    # Delayed::Job.enqueue ProcessFriends.new(params["id"].to_i)
    
    respond_to do |format|
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
  
  def remash
    Rails.logger.info request.query_parameters.inspect
    
    # LOGGING TO DATABASE
    logging(request, "remash", params[:mode].to_i)
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    respond_to do |format|
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end

  def result
    # This API will calculate the result of a mash and adjust scores for winner and loser
    # It will also fire a delayed job to insert a record into the Results table
    # Response is a simple JSON "success" => "true" that is ignored by the client
    
    Rails.logger.info request.query_parameters.inspect
    
    # LOGGING TO DATABASE
    logging(request, "result", params[:mode].to_i)
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # puts request.env["HTTP_X_USER_ID"]
    # puts request.env["HTTP_X_UDID"]
    
    # check to see if current player exists
    player = User.find_by_facebook_id(params[:id].to_i)
    
    # Increment vote count for current user
    # If network only mode, increment votes_network also
    
    if not player.nil?
      Profile.increment_counter('votes',Profile.find_by_facebook_id(params[:id].to_i).id)
      if params[:mode].to_i > 0
        Profile.increment_counter('votes_network',Profile.find_by_facebook_id(params[:id].to_i).id)
      end
    end
    
    winner = User.find_by_facebook_id(params[:w].to_i)
    loser  = User.find_by_facebook_id(params[:l].to_i)
    
    # Store the score of the winner/loser before we calculate the new scores
    # These old scores get passed into the Results table
    winnerBeforeScore = winner[:score]
    loserBeforeScore = loser[:score] 
    
    # Adjust scores for winner/loser for this mash
    adjustScoresForUsers(winner, loser, params[:mode].to_i)
    
    # Adjust judge-factor of player; only adjust if it's decisive enough for user to make a choice    
    if not player.nil?
      outcomeChance = expected_outcome_by_score(winnerBeforeScore, loserBeforeScore)
      judgeFactorBefore = player.judge_factor
      if (0.50-outcomeChance).abs > 0.03 && (winner.wins + winner.losses)>5 && (loser.wins+loser.losses)>5
        if winnerBeforeScore>loserBeforeScore
          judgeFactorAfter = judgeFactorBefore + ( 32-(1500-judgeFactorBefore).abs/15.0)
        else
          judgeFactorAfter = judgeFactorBefore - ( 32-(1500-judgeFactorBefore).abs/15.0)
        end
        player.update_attributes(
          :judge_factor => judgeFactorAfter
        )
      end
    else
      judgeFactorBefore = 1337
    end
    
    # Insert a NEW record into Result table to keep track of the fight
    # If left is true, that means left side was DISCARDED
    Delayed::Job.enqueue GenerateResult.new(params[:id].to_i, params[:w].to_i, params[:l].to_i, params[:left], params[:mode].to_i, winnerBeforeScore, loserBeforeScore, judgeFactorBefore, winner.gender)

    respond_to do |format|
      format.xml  { render :xml => {:success => "true"} }
      format.json  { render :json => {:success => "true"} }
    end
  end
  
  def profile
    # Given a parameter facebookId
    # Return a hash of a given user's profile
    
    Rails.logger.info request.query_parameters.inspect
    
    # LOGGING TO DATABASE
    logging(request, "profile")
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    profileHash = {}
    
    user = User.select('*').where('facebook_id' => params[:id].to_i).joins(:profile).first
    
    # if somehow this user doesn't exist...
    if user.nil?
      profileHash['full_name'] = "Server Error! Please logout and login again!"
      profileHash['stats'] = []
      
      respond_to do |format|
        format.xml  { render :xml => profileHash }
        format.json  { render :json => profileHash }
      end
      return nil
    end
    
    # Section 0 in client
    profileHash['full_name'] = user['full_name']
    profileHash['votes'] = user['votes'].to_i
    profileHash['votes_network'] = user['votes_network'].to_i
    
    # Section 1 in client
    profileHash['stats'] = []
    
    query = "select sum(case when a.score>b.score then 1 else 0 end) as rankoftotal,
     sum(case when a.score>b.score AND c.friend_id is not null then 1 else 0 end) as rankofnetwork,
      sum(case when c.friend_id is not null then 1 else 0 end) as networktotal,
       count(*) as total from users a left join users b on 1=1 and b.facebook_id='#{user['facebook_id']}'
        left join networks c on c.friend_id = a.facebook_id and c.facebook_id=b.facebook_id where a.gender = b.gender"
    
    # if Rails.env == "production" || Rails.env == "staging"
    #   ranksHash = ActiveRecord::Base.connection.execute(query).fetch_hash
    # else
    #   ranksHash = ActiveRecord::Base.connection.execute(query)[0]
    # end
    ranksHash = ActiveRecord::Base.connection.execute(query).fetch_hash
    
    # Number of friends also playing friendmash
    query = "select count(*) as friendsonfriendmash from tokens where facebook_id in (select friend_id from networks where facebook_id=#{user['facebook_id']})"
    otherStatsHash = ActiveRecord::Base.connection.execute(query).fetch_hash
    
    # Accuracy
    query = "select coalesce(round(accurate/(total-unranked)*100,2),'N/A') as accuracy,
           coalesce(total-unranked, 'N/A') as ranked,
           coalesce(unranked, 'N/A') as unranked
    from (
    select sum(case when a.winner_score>=a.loser_score and a.winner_score<>1500 and a.loser_score<>1500
      then 1 else 0 end) as accurate,
    sum(case when a.winner_score=1500 or a.loser_score=1500 or a.winner_score is null then 1 else 0 end) as unranked,
    count(*) as total
    from results a where facebook_id = #{user['facebook_id']}) a"
    accuracyHash = ActiveRecord::Base.connection.execute(query).fetch_hash
        
    profileHash['stats'] << { :name => "Friends on Friendmash", :value => "#{otherStatsHash['friendsonfriendmash'].to_i}" }
    profileHash['stats'] << { :name => "Ranking among Everyone", :value => "#{ranksHash['rankoftotal'].to_i + 1} / #{ranksHash['total']}" }
    profileHash['stats'] << { :name => "Ranking among Friends", :value => "#{ranksHash['rankofnetwork'].to_i + 1} / #{ranksHash['networktotal'].to_i + 1}" }
    profileHash['stats'] << { :name => "Likes Received", :value => "#{user['wins']}" }
    profileHash['stats'] << { :name => "Longest Like Streak", :value => "#{user['win_streak_max']}" }
    profileHash['stats'] << { :name => "Choosing the correct winner (%)", :value => "#{accuracyHash['accuracy']}" }
    profileHash['stats'] << { :name => "Ranked Mashes Played", :value => "#{accuracyHash['ranked']}" }
    profileHash['stats'] << { :name => "Unranked Mashes Played", :value => "#{accuracyHash['unranked']}" }
    
    # profileHash['stats'] << { :name => "Total Time Played", :value => "5" }
    # profileHash['stats'] << { :name => "Mashes in Last 24 Hours", :value => "1" }
    # profileHash['stats'] << { :name => "Mashes in Last 7 Days", :value => "2" }
    
    # send response
    respond_to do |format|
      format.xml  { render :xml => profileHash }
      format.json  { render :json => profileHash }
    end
  end
  
  def topplayers
    # This API will find the top COUNT (99 default) players with the highest votes (mashes)
    # Response is an array of hashes that represent Users/Profiles of the players
    
    Rails.logger.info request.query_parameters.inspect
    
    # LOGGING TO DATABASE
    logging(request, "topplayers")
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # If the client does not pass a count param, default to 99
    if params[:count].nil?
      count = 99
    else
      count = params[:count].to_i
    end
    
    # Only show players who have more than 0 mashes
    topPlayers = Profile.all(:conditions=>"votes > 0",:order=>"votes desc",:limit=>count)
    
    rankings = []
    
    topPlayers.each_with_index do |profile,rank|
      rankingsHash = {
        :facebook_id => profile[:facebook_id].to_s,
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
    # This API returns the top COUNT (99 default) Users based on score for a gender
    # The response is a JSON array of hashes that represent Users/Profiles
    
    Rails.logger.info request.query_parameters.inspect
    # Rails.logger.info request.env.inspect
    
    # LOGGING TO DATABASE
    logging(request, "rankings", params[:mode].to_i, params[:gender])
    
    if request.env["HTTP_X_FRIENDMASH_SECRET"] != FRIENDMASH_SECRET
      respond_to do |format|
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    # If the client does not pass a count param, default to 99
    if params[:count].nil?
      count = 99
    else
      count = params[:count].to_i
    end
    
    # if network only is on, generate the sql string
    networkIds = []

    if params[:mode].to_i == 1
      Network.where("facebook_id = #{params[:id].to_i}").each do |network|
        networkIds << network.friend_id
      end
      networkString = networkIds.join(',')
    elsif params[:mode].to_i == 2
      networkIds = network_cache(params[:id].to_i)
    elsif params[:mode].to_i == 3
      networkIds = classmate_cache(params[:id].to_i)
    end
    
    # Active Record Join Alternative
    # users = User.select('*').all(:conditions=>"gender = '#{params[:gender]}'",:order=>"score desc",:limit=>count,:joins=>:profile)
    if networkIds.empty?
      users = User.all(:conditions=>"gender = '#{params[:gender]}'",:order=>"score desc,wins+losses+0.5*(wins_network+losses_network)",:limit=>count,:include=>:profile)
    else
      networkString = networkIds.join(',')
      users = User.all(:conditions=>"gender = '#{params[:gender]}' AND wins+losses>0 AND facebook_id IN (#{networkString})",:order=>"score desc,wins+losses+0.5*(wins_network+losses_network)",:limit=>count,:include=>:profile)      
      # users = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id IN (#{networkString})",:order=>"score desc",:limit=>count,:include=>:profile)
    end
    
    rankings = []
    users.each_with_index do |user,rank|
      actualScore = user[:score]
      # if params[:mode].to_i == 0
      actualWins = user[:wins] + user[:wins_network]
      actualLosses = user[:losses] + user[:losses_network]
      actualWinStreak = user[:win_streak] > user[:win_streak_network] ? user[:win_streak] : user[:win_streak_network]
      actualLossStreak = user[:loss_streak] > user[:loss_streak_network] ? user[:loss_streak] : user[:loss_streak_network]
      actualWinStreakMax = user[:win_streak_max] > user[:win_streak_max_network] ? user[:win_streak_max] : user[:win_streak_max_network]
      actualLossStreakMax = user[:loss_streak_max] > user[:loss_streak_max_network] ? user[:loss_streak_max] : user[:loss_streak_max_network]
      # else
      #   actualWins = user[:wins_network]
      #   actualLosses = user[:losses_network]
      #   actualWinStreak = user[:win_streak_network]
      #   actualLossStreak = user[:loss_streak_network]
      #   actualWinStreakMax = user[:win_streak_max_network]
      #   actualLossStreakMax = user[:loss_streak_max_network]
      # end
      rankingsHash = {
        :facebook_id => user[:facebook_id].to_s,
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
  
  #
  # NON-API Internal Methods
  #
  
  def network_cache(facebookId)
    # This wrapper uses an RDS table as a cache for 2nd degree network generation
    # Each row is keyed off facebook_id and has a TEXT BLOB value for a CSV of friend_id and an expire
    # If the cache misses, execute the SQL query and insert into cache
    #
    # Arguments: facebook_id
    # Return: array of friend_id
    
    
    # if network only is on, generate the sql string
    # networkIds = []
    # if params[:mode].to_i == 1
    #   Network.where("facebook_id = #{params[:id]}").each do |network|
    #     networkIds << network.friend_id
    #   end
    #   networkString = networkIds.join(',')
    # elsif params[:mode].to_i == 2
    #   networkIds = network_cache(params[:id])
    # end
    #
    
    friendIdArray = []    
    
    # User.count(["last_time >= ?", 7.days.ago])
    
    cache = NetworkCache.where("facebook_id = #{facebookId} AND expires_at > ?", Time.now).first
    
    if cache.nil?
      # if we had a cache miss, we need to execute the fetch/insert query
      puts "Cache miss"
  
      query = "select distinct friend_id
      from networks where facebook_id in (select friend_id from networks where facebook_id=#{facebookId})
      or facebook_id in (#{facebookId})"
      friendIdArray = ActiveRecord::Base.connection.select_values(query)      

      # check for empty network array
      if friendIdArray.empty?
        # try to get first degree connections for now
        # don't cache it
        friendIdArray = Network.where("facebook_id = #{facebookId}").map do |friend| friend.friend_id end
      else
        # Create or update cache
        cache = NetworkCache.find_or_initialize_by_facebook_id(facebookId)
        cache.network = friendIdArray.join(',')
        cache.expires_at = Time.now + 1.days
        cache.save
      end
    else
      puts "Cache hit"
      # check for an empty cache
      if cache[:network].empty?
        cache.expires_at = Time.now - 1.days # force expire it
        cache.save
      end
      friendIdArray = cache[:network].split(',')
    end
    
    # puts "Found friend id array"
    # p friendIdArray
    
    return friendIdArray
  end
  
  def classmate_cache(facebookId)
    classmateIdArray = []
    
    cache = ClassmateCache.where("facebook_id = #{facebookId} AND expires_at > ?", Time.now).first
    
    if cache.nil?
      schoolIdArray = User.find_by_facebook_id(facebookId).schools.select('school_id').map do |s| s.school_id end
      if schoolIdArray.empty?
        classmateIdArray = network_cache(facebookId)
      else
        classmateIdArray = User.select('DISTINCT(users.facebook_id)').where("school_id IN (#{schoolIdArray.join(',')})").joins(:schools,:profile).map do |u| u.facebook_id end
        classmateIdArray.delete(facebookId) # remove own facebookId
      end
      
      # check for empty classmate array
      if classmateIdArray.empty?
        # try to get first degree connections for now
        # don't cache it
        classmateIdArray = Network.where("facebook_id = #{facebookId}").map do |friend| friend.friend_id end
      else
        # create or update cache
        cache = ClassmateCache.find_or_initialize_by_facebook_id(facebookId)
        cache.classmates = classmateIdArray.join(',')
        cache.expires_at = Time.now + 1.days
        cache.save
      end
    else
      if cache[:classmates].empty?
        cache.expires_at = Time.now - 1.days # force expire it
        cache.save
      end
      classmateIdArray = cache[:classmates].split(',')
    end
    
    return classmateIdArray
  end
  
  def find_opponent(desiredScore, gender, excludedIds = [], networkIds = [], facebookId = nil, mode = 0)
    # This API finds an opponent close to the desired score who is not:
    # Part of the excludedIds
    # If network only mode is on, the opponent in the set of networkIds
    # It will return a single User entity as the opponent
    
    # First hit the DB with a CSV of excluded IDs and a match_score +/- match_range
    # Fetch an array of valid IDs from DB who match the +/- range from the current user's score
    # The array of IDs should be calculated from the forumla calculate_bounds
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
    #
    # Need to add a count in the future that handles mode=2 social network count
    if mode == 0
      population = User.where("gender = '#{gender}'").count.to_f # Get the total population size of the user's table for this gender
    else
      # Because we don't store gender in the network table, we can't filter on gender for now
      # population = Network.where("facebook_id = #{facebookId} AND gender = '#{gender}'").count
      population = Network.where("facebook_id = #{facebookId}").count.to_f
    end
    
    # Perform a score bias when finding opponent
    desiredScore = desiredScore + 32
    
    # Approx sample size
    sampleSize = 1000.0
    
    # Default standard deviation
    standardDeviation = 282.0
    
    # Override with true standard deviation; in the future calculate using query
    # Everyone male - 31, Everyone female 52.
    standardDeviation = 31.0
    
    # Calculate the low and high end bounds
    # NOTE: MAKE SURE WE ARE PASSING IN FLOATS AND NOT INTEGERS!!!!! OMGWTFBBQ
    if mode > 0
      low = 600
      high = 2400
    else
      bounds = calculate_bounds(desiredScore, population, 1500.0, standardDeviation, sampleSize)
      low = bounds[0]
      high = bounds[1]
    
      # Adding this for good measure
      if high-low<100
        high = low+100
      end
      
      # Apply an override so that we just statically get opponents that are +/- 100 points
      # until we figure out a better algorithm
      # low = desiredScore - 100
      # high = desiredScore + 100
    end
    
    puts "desiredScore: #{desiredScore}"
    puts "population: #{population}"
    puts "stdDev: #{standardDeviation}"
    puts "sampleSize: #{sampleSize}"
    puts "lower: #{low}"
    puts "upper: #{high}"
    
    # if Rails.env == "production" || Rails.env == "staging"
    #   randQuery = 'RAND()'
    # else
    #   randQuery = 'RANDOM()'
    # end
    randQuery = 'RAND()'
    
    # Network only mode should only search in a restricted SET of Users
    if networkIds.empty?
      excludedString = excludedIds.join(',') # SQL string for excludedIds
      opponent = User.all(:conditions=>"score >= #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id NOT IN (#{excludedString})",:order=>randQuery,:select =>"facebook_id",:limit=>1)
    else
      networkString = networkIds.join(',') 
      opponent = User.all(:conditions=>"score >= #{low} AND score <= #{high} AND gender = '#{gender}' AND facebook_id IN (#{networkString})",:order=>randQuery,:select =>"facebook_id",:limit=>1)
    end
  
    return opponent.first
  end
  
  def adjustScoresForUsers(winner, loser, mode = 0)
    # This method calculates and adjusts the score and stats for the winner and loser
    
    winnerExpected = expected_outcome(winner, loser)
    loserExpected = expected_outcome(loser, winner)
    
    # Decrease score change factor when playing in network mode to discount favoritism for friends
    if mode >0
      factor = 0.25
    else
      factor = 0.5
    end
    
    # Weighs in users standard deviation (ie credibility of opponent)
    stdDiv = ( (winner[:std])**2 + (loser[:std])**2 ) ** 0.5
    #winnerNewScore = winner[:score] + (32 * (winner[:std])**2 / (stdDiv * 216.0) * (1 - winnerExpected))
    #loserNewScore = loser[:score] + (32 * (loser[:std])**2 / (stdDiv * 216.0) * (0 - loserExpected))
    winnerNewScore = winner[:score] + factor * ((winner[:std])**2 / (stdDiv) * (1 - winnerExpected))
    loserNewScore = loser[:score] + factor * ((loser[:std])**2 / (stdDiv) * (0 - loserExpected))
    
    # Change standard dev of scores; could be a tie game then don't change std
    # if expected result decrease std = user - (user^2 / (user^2 + opp^2)^0.5)^0.6
    # if unexpected result increase std = user + (same)
    if winnerExpected >= 0.53
      loserStd = [loser.std - (loser.std**2 / (winner.std**2 + loser.std**2)**0.5)**0.6, 121].max
      winnerStd = [winner.std - (winner.std**2 / (loser.std**2 + winner.std**2)**0.5)**0.6, 121].max
    elsif winnerExpected <=0.47
      loserStd = [loser.std + (loser.std**2 / (winner.std**2 + loser.std**2)**0.5)**0.6, 242].min
      winnerStd = [winner.std  + (winner.std**2 / (loser.std**2 + winner.std**2)**0.5)**0.6, 242].min
    else
      loserStd = loser.std
      winnerStd = winner.std
    end
    
    # Adjust the winner score
    winner.update_attributes(
      :wins => (mode == 0) ? winner[:wins] + 1 : winner[:wins],
      :wins_network => (mode > 0) ? winner[:wins_network] + 1 : winner[:wins_network],
      :win_streak => (mode == 0) ? winner[:win_streak] + 1 : winner[:win_streak],
      :win_streak_network => (mode > 0)? winner[:win_streak_network] + 1 : winner[:win_streak_network],
      :loss_streak => (mode == 0) ? 0 : winner[:loss_streak],
      :loss_streak_network => (mode > 0) ? 0 : winner[:loss_streak_network],
      :score => winnerNewScore,
      :win_streak_max => (mode == 0) ? ( winner[:win_streak] + 1 > winner[:win_streak_max] ? winner[:win_streak] + 1: winner[:win_streak_max] ) : winner[:win_streak_max],
      :win_streak_max_network => (mode > 0) ? ( winner[:win_streak_network] + 1 > winner[:win_streak_max_network] ? winner[:win_streak_network] + 1 : winner[:win_streak_max_network] ) : winner[:win_streak_max_network],
      :std => winnerStd
    )
    
    # Adjust the loser score
    loser.update_attributes(
      :losses => (mode == 0) ? loser[:losses] + 1 : loser[:losses],
      :losses_network => (mode > 0) ? loser[:losses_network] + 1 : loser[:losses_network],
      :loss_streak => (mode == 0) ? loser[:loss_streak] + 1 : loser[:loss_streak],
      :loss_streak_network => (mode > 0) ? loser[:loss_streak_network] + 1 : loser[:loss_streak_network],
      :win_streak => (mode == 0) ? 0 : loser[:win_streak],
      :win_streak_network => (mode > 0) ? 0 : loser[:win_streak_network],
      :score => loserNewScore,
      :loss_streak_max => (mode == 0) ? ( loser[:loss_streak] + 1 > loser[:loss_streak_max] ? loser[:loss_streak] + 1 : loser[:loss_streak_max] ) : loser[:loss_streak_max],
      :loss_streak_max_network => (mode > 0) ? ( loser[:loss_streak_network]  + 1 > loser[:loss_streak_max_network] ? loser[:loss_streak_network] + 1 : loser[:loss_streak_max_network] ) : loser[:loss_streak_max_network],
      :std => loserStd
    )
    
    return nil
  end
  
  def expected_outcome(user, opponent)    
    # Calculate the expected outcomes of a mash between two users
    
    exponent = 10.0 ** ((opponent[:score] - user[:score]) / 400.0)
    expected = 1.0 / (1.0 + exponent)
    
    return expected
  end
  
  def expected_outcome_by_score(user, opponent)    
    # Calculate the expected outcomes of a mash between two users
    
    exponent = 10.0 ** ((opponent - user) / 400.0)
    expected = 1.0 / (1.0 + exponent)
    
    return expected
  end
  
  def calculate_bounds(userScore, pop, popAverage, popSD, sampleSize)
    # Uses a normal distribution formula
    # Calculates the low and high bounds for selecting an opponent
    # Returns an array [low, high]
    
    k_low = (-1 * (sampleSize.to_f / pop.to_f))
    k_high = (1 * (sampleSize.to_f / pop.to_f))

    array_returns_low = (600..userScore).map { |i|
      (k_low.to_f + Math.erf((userScore.to_f-popAverage.to_f)/(popSD.to_f*(2.0**0.5))) - Math.erf((i.to_f-popAverage.to_f)/(popSD.to_f*(2.0**0.5)))).abs
    }

    array_returns_high = (userScore..2400).map { |i|
      (k_high.to_f + Math.erf((userScore.to_f-popAverage.to_f)/(popSD.to_f*(2.0**0.5))) - Math.erf((i.to_f-popAverage.to_f)/(popSD.to_f*(2.0**0.5)))).abs
    }

    return [(600..userScore).to_a[array_returns_low.index(array_returns_low.min)], (userScore..2400).to_a[array_returns_high.index(array_returns_high.min)]]
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
  
  # takes a gzipped string and deflates it
  def inflate(string)
    zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    buf = zstream.inflate(string)
    zstream.finish
    zstream.close
    buf
  end
  
  # Stats APIs
  def recents
    Rails.logger.info request.query_parameters.inspect
    
    if params[:count].nil?
      count = 50
    else
      count = params[:count].to_i
    end
    
    if params[:filter].nil? || params[:filter] == "false"
      results = Result.all(:order=>"created_at desc", :limit=>count)
    else       
      results = Result.all(:conditions =>"facebook_id = #{params[:id].to_i}",:order=>"created_at desc", :limit=>count)
    end
    
    response = []
    results.each do |result|
      responseHash = { 
        :facebook_id => result[:facebook_id].to_s,
        :winner_id => result[:winner_id].to_s,
        :loser_id => result[:loser_id].to_s,
        :winner_score => result[:winner_score],
        :loser_score => result[:loser_score],
        :created_at => result[:created_at]
      }
      response << responseHash
    end
    
    respond_to do |format|
      format.xml  { render :xml => response }
      format.json  { render :json => response }
    end
  end
  
  def activity
    # THIS ONLY works in MYSQL
    
    # This API returns a JSON response for recent server activity for the Web client to render.
    # This is admin only and should be restricted/authenticated
    Rails.logger.info request.query_parameters.inspect
    
    # Interval can be any integer > 0
    # Period can be { hour, day }
    
    if params[:fields].nil? 
      fields = %w(users profiles tokens networks results employers schools)
      # fields = %w(users profiles)
    else
      fields = params[:fields].split(',')
    end
    
    if params[:interval].nil?
      interval = "24"
    else
      interval = params[:interval]
    end
    
    if params[:period].nil?
      period = "hour"
    else
      period = params[:period]
    end
    
    response = {}
    
    fields.each do |field|
      if period == "day"
        query = "select year(dt) as year, month(dt) as month, day(dt) as day, coalesce(b.data,0) as data
                  from calendar a
                  left join (select date(created_at) as date, count(*) as data
                            from #{field} where created_at > (select now() - interval #{interval} #{period})
                            group by date(created_at)) b
                  on date(a.dt) = b.date
                  where dt between (select now()- interval #{interval} #{period}) and (select now()) and hour(a.dt)=0"
      else
        query = "select year(dt) as year, month(dt) as month, day(dt) as day, hour(dt) as hour, coalesce(b.data,0) as data
                  from calendar a
                  left join (select date(created_at) as date, hour(created_at) as hour, count(*) as data
                            from #{field} where created_at > (select now() - interval #{interval} #{period})
                            group by date(created_at), hour(created_at)) b
                  on date(a.dt) = b.date and hour(a.dt) = b.hour
                  where dt between (select now()- interval #{interval} #{period}) and (select now())"        
      end
                
      mysqlresults = ActiveRecord::Base.connection.execute(query)
      
      response["#{field}"] = {}
      response["#{field}"]['values'] = []
      response["#{field}"]['count'] = mysqlresults.num_rows
      
      while mysqlresult = mysqlresults.fetch_hash do
        response["#{field}"]['values'] << mysqlresult
      end
      
      mysqlresults.free
    end

    respond_to do |format|
      format.xml  { render :xml => response }
      format.json  { render :json => response }
    end
  end
  
  def serverstats
    # This API returns a JSON response for server stats for the Web client to render.
    # This is admin only and should be restricted/authenticated
    Rails.logger.info request.query_parameters.inspect
    
    if params[:fields].nil? 
      fields = %w(users profiles tokens networks results employers schools)
    else
      fields = params[:fields].split(',')
    end
    
    response = {}
    
    query = "select
              TABLE_SCHEMA,
              TABLE_NAME,
              concat(table_rows) rows,
              concat(data_length) data_size,
              concat(index_length) idx_size,
              concat(data_length + index_length) total_size,
              round(index_length/data_length,2) idx_frac
              from information_schema.TABLES s
              where table_schema = 'friendmash'
              order by data_length+index_length desc"
              
    mysqlresults = ActiveRecord::Base.connection.execute(query)
    
    while mysqlresult = mysqlresults.fetch_hash do
      response["#{mysqlresult['TABLE_NAME']}"] = mysqlresult
    end
    
    mysqlresults.free
    
    respond_to do |format|
      format.xml  { render :xml => response }
      format.json  { render :json => response }
    end
  end
  
  def stats
    # This API returns a JSON response for mash stats
    if params[:interval].nil?
      interval = "24"
    else
      interval = params[:interval]
    end
    
    if params[:period].nil?
      period = "hour"
    else
      period = params[:period]
    end
  
    if params[:filter].nil? || params[:filter] == "false"
      filters = ""
    else
      filters = "and facebook_id = #{params[:id].to_i}"
    end
    
    response = []

    query = "select year(dt) as year, month(dt) as month, day(dt) as day, coalesce(b.data,0) as data
              from calendar a
              left join (select date(created_at) as date, count(*) as data
                        from results where created_at > (select now() - interval #{interval} #{period})
                        group by date(created_at)) b
              on date(a.dt) = b.date
              where dt between (select now()- interval #{interval} #{period}) and (select now()) and hour(a.dt)=0"
  				
    mysqlresults = ActiveRecord::Base.connection.execute(query)

    while mysqlresult = mysqlresults.fetch_hash do
      response << mysqlresult
    end

    mysqlresults.free
    
    respond_to do |format|
      format.xml  { render :xml => response }
      format.json  { render :json => response }
    end
  end
  
  # def globalstats
  #   # This API returns a JSON response for server stats for the Web client to render.
  #   # This is admin only and should be restricted/authenticated
  #   Rails.logger.info request.query_parameters.inspect
  #   
  #   response = []
  #   
  #   query = "select id, name, value from statistic_summary;"
  #   mysqlresults = ActiveRecord::Base.connection.execute(query)    
  # 
  #   while mysqlresult = mysqlresults.fetch_hash do
  #     response << mysqlresult
  #   end
  # 
  #   mysqlresults.free
  #   
  #   respond_to do |format|
  #     format.xml  { render :xml => response }
  #     format.json  { render :json => response }
  #   end
  # end

  def globalstats
    # LOGGING TO DATABASE
    logging(request, "globalstats")

    #dc = Dalli::Client.new('127.0.0.1:11211',{:expires_in=>15.minutes})
    globalstats = Rails.cache.read("globalstats")
    response = []
    
    if globalstats == nil
      updateStatisticSummary

      query = "select concat(name,' : ', cast(format(value,0) as char)) as stat from statistic_summary;"
      mysqlresults = ActiveRecord::Base.connection.execute(query)    

      while mysqlresult = mysqlresults.fetch_hash do
        response << mysqlresult['stat']
      end
      mysqlresults.free

      response << "If you like friendmash, let us know by rating us on iTunes!"
      # response << "Search 'FriendMash' on Facebook and become a fan!"
      
      globalstats = Rails.cache.write('globalstats', response, :expires_in => 15.minutes)
      
    else
      response = globalstats
    end

    respond_to do |format|
      format.xml  { render :xml => response }
      format.json  { render :json => response }
    end

  end

  # General purpose logging
  def logging(request, actiontype, var1=nil, var2=nil)
    
    if request.env["HTTP_X_USER_ID"].nil?
      facebook_id =  params[:id]
    else
      facebook_id = request.env["HTTP_X_USER_ID"]
    end
    
    if request.env["HTTP_X_VAR1"].nil?
    else
      var1 = request.env["HTTP_X_VAR1"]
    end    

    if request.env["HTTP_X_VAR2"].nil?
    else
      var2 = request.env["HTTP_X_VAR2"]
    end
    
    logs = Logs.create(
      :event_timestamp => Time.now,
      :session_starttime => request.env["HTTP_X_SESSION_KEY"].nil? ? '1900-01-01' : Time.at(request.env["HTTP_X_SESSION_KEY"].to_i),
      :udid => request.env["HTTP_X_UDID"].nil? ? nil: request.env["HTTP_X_UDID"],
      :device_model => request.env["HTTP_X_DEVICE_MODEL"].nil? ? nil: request.env["HTTP_X_DEVICE_MODEL"],
      :system_name => request.env["HTTP_X_SYSTEM_NAME"].nil? ? nil: request.env["HTTP_X_SYSTEM_NAME"],
      :system_version => request.env["HTTP_X_SYSTEM_VERSION"].nil? ? nil: request.env["HTTP_X_SYSTEM_VERSION"],
      :app_version => request.env["HTTP_X_APP_VERSION"].nil? ? nil: request.env["HTTP_X_APP_VERSION"],
      :facebook_id => facebook_id.nil? ? nil: facebook_id,
      :connection_type => request.env["HTTP_X_CONNECTION_TYPE"].nil? ? nil: request.env["HTTP_X_CONNECTION_TYPE"],
      :language => request.env["HTTP_X_USER_LANGUAGE"].nil? ? nil: request.env["HTTP_X_USER_LANGUAGE"],
      :locale => request.env["HTTP_X_USER_LOCALE"].nil? ? nil: request.env["HTTP_X_USER_LOCALE"],
      :action_type => actiontype.nil? ? nil: actiontype,
      :var1 => var1.nil? ? nil: var1,
      :var2 => var2.nil? ? nil: var2
    )
    
  end

end
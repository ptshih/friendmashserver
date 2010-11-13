# Achievement icon/badges go into profile page
# special rankings, maybe chevrons, wow pvp ranking badges
# win streak crown
# location based: mayor of location


class MashController < ApplicationController
  require 'generate_second_degree' 
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
      randQuery = 'RANDOM()'
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
    
    # puts "LOL"
    # p randomUser
    if not randomUser.nil?
      opponent = findOpponentForUser(randomUser.score, params[:gender], randomUser.facebook_id, recentIds, networkIds)
      
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
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id != :currentId AND facebook_id IN (#{networkIds})", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      end
    else
      if networkIds.nil?
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      else
        bucket = User.where(["score >= :lowScore AND score <= :highScore AND gender = :gender AND facebook_id NOT IN (#{recentIds}) AND facebook_id IN (#{networkIds}) AND facebook_id != :currentId", { :lowScore => (desiredScore - range), :highScore => (desiredScore + range), :gender => gender, :currentId => currentId }]).select("facebook_id, score")
      end
    end
    
    if bucket.length > 0
      opponentIndex = binarySearch(bucket, desiredScore, 0, bucket.length - 1)
      opponent = bucket[opponentIndex]
    else
      return nil # no opponent found
    end
    
    # puts opponent
    
    return opponent
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
    
    opponent = findOpponentForUser(user.score, params[:gender], params[:id], recentIds, nil)
    
    # puts opponent.facebook_id
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => opponent.facebook_id }
      format.json  { render :json => opponent.facebook_id }
    end
  end 
  
  # takes a gzipped string and deflates it
  def inflate(string)
    zstream = Zlib::Inflate.new(-Zlib::MAX_WBITS)
    buf = zstream.inflate(string)
    zstream.finish
    zstream.close
    buf
  end
  
  def friends
    # upload some users friends to save in the db
    
    # Rails.logger.info request.query_parameters.inspect
    
    if request.env["HTTP_X_FACEMASH_SECRET"] != "omgwtfbbq"
      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => {:error => "access denied"} }
        format.json  { render :json => {:error => "access denied"} }
      end
      return nil
    end
    
    friendIdArray = []
    
    currentUser = User.find_by_facebook_id(params[:id])
    
    # ActiveRecord::Base.execute("REPLACE INTO 'token' SET 'facebook_id' = ")
    token = Token.find_by_facebook_id(params[:id])
    if token.nil?
      token = Token.create(
        :facebook_id => params[:id],
        :access_token => params[:access_token],
        :udid => request.env["HTTP_X_UDID"]
      )
    else
      # token.update_attribute('access_token', params[:access_token])
      token.update_attributes(
        :access_token => params[:access_token],
        :udid => request.env["HTTP_X_UDID"]
      )
    end
    
    # We should always be expecting a GZIP postData here
    # params[:_json] || 
    json = JSON.parse(Zlib::GzipReader.new(StringIO.new(request.raw_post.to_s)).read)

    # puts "json = #{json.inspect}"
    json.each do |user|
      if User.find_by_facebook_id(user['id']).nil?
        User.new do |u|
          u.facebook_id = user['id']
          u.gender = user['gender']
          u.score = 1500
          u.wins = 0
          u.losses = 0
          u.win_streak = 0
          u.loss_streak = 0
          u.save
        end
        Profile.new do |p|
          p.facebook_id = user['id']
          p.first_name = user['first_name']
          p.middle_name = user['middle_name'].nil? ? nil : user['middle_name']
          p.last_name = user['last_name']
          p.full_name = user['name']
          p.birthday = user['birthday'].nil? ? nil : user['birthday']
          p.relationship_status = user['relationship_status'].nil? ? nil : user['relationship_status']
          p.location = user['location'].nil? ? nil : user['location']['name']
          p.hometown = user['hometown'].nil? ? nil : user['hometown']['name']
          p.votes = 0
          p.votes_network = 0
          p.save
        end

        user['education'].each do |education|
          School.new do |s|
            s.facebook_id = user['id']
            s.school_id = education['school']['id']
            s.school_name = education['school']['name']
            s.save
          end
        end if not user['education'].nil?
          
        user['work'].each do |work|
          Employer.new do |e|
            e.facebook_id = user['id']
            e.employer_id = work['employer']['id']
            e.employer_name = work['employer']['name']
            e.save
          end
        end if not user['work'].nil?
      else        
        profile = Profile.find_by_facebook_id(user['id'])
        profile.update_attributes(
          :first_name => user['first_name'],
          :middle_name => user['middle_name'].nil? ? nil : user['middle_name'],
          :last_name => user['last_name'],
          :full_name => user['name'],
          :birthday => user['birthday'].nil? ? nil : user['birthday'],
          :relationship_status => user['relationship_status'].nil? ? nil : user['relationship_status'],
          :location => user['location'].nil? ? nil : user['location']['name'],
          :hometown => user['hometown'].nil? ? nil : user['hometown']['name']
        )
      end
      
      # Insert friend into friendIdArray
      if not params[:id] == user['id']
        friendIdArray << user['id']
      end
    end
    
    # Generate first degree network for this user
    generateFirstDegree(params[:id], friendIdArray)
    # self.send_later(:generateSecondDegreeNetworkForUser, params[:id])
    
    Delayed::Job.enqueue GenerateSecondDegree.new(params[:id])  
    
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
    
    winner = User.find_by_facebook_id(params[:w].to_s)
    loser  = User.find_by_facebook_id(params[:l].to_s)
    
    adjustScoresForUsers(winner, loser)
    
    # Insert a NEW record into Result table to keep track of the fight
    # If left is true, that means left side was DISCARDED
    Result.new do |r|
      r.facebook_id = params[:id]
      r.winner_id = params[:w]
      r.loser_id = params[:l]
      r.left = params[:left]
      r.save
    end
    
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
    
    profile = User.select('*').where('facebook_id' => params[:id]).joins(:profile).first
    
    # send response
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => profile }
      format.json  { render :json => profile }
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
      count = 25
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
      users = User.all(:conditions=>"gender = '#{params[:gender]}' AND facebook_id IN (#{networkIds})",:order=>"score desc",:limit=>count,:include=>:profile)
    end
    
    rankings = []
    
    users.each_with_index do |user,rank|
      rankingsHash = {
        :facebook_id => user[:facebook_id],
        :full_name => user.profile[:full_name],
        :score => user[:score],
        :wins => user[:wins],
        :losses => user[:losses],
        :win_streak => user[:win_streak],
        :loss_streak => user[:loss_streak],
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

  def generateFirstDegree(facebookId, friendIdArray)
#    friendIdArray = ["1217270","1217767","1209924"]
    # This method generates a network link table of user -> friend with degree = 1
    puts "Generate 1st degree network link table for user with id: #{facebookId}"

    friendIdArray.each do |friendId|
      if Network.where(["facebook_id = :facebook_id AND friend_id = :friend_id", { :facebook_id => facebookId, :friend_id => friendId }]).empty?
        network = Network.create(
          :facebook_id => facebookId,
          :friend_id => friendId, 
          :degree => 1
        )
      end
    end
    
    return nil
  end
  
end
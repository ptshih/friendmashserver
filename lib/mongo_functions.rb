require 'mongo'

# only populating first degree
def populatemongonetwork
  
  db = Mongo::Connection.new("localhost", 27017).db("networks")
  
  #coll = db.collection("masterNetwork")
  
  Network.where("degree=1").find_each(:batch_size => 5000) do |network|  
    coll = db.collection(network['facebook_id'])
    #doc = {"_id"=> User.find_by_facebook_id(network['friend_id']).id, "d"=>network['degree']}
    doc = {"_id"=> network['friend_id'], "d"=>network['degree']}
    coll.insert(doc)    
  end
  
end



# populates 2nd degree
def populatedegree(facebook_id, degree)
    db = Mongo::Connection.new("localhost", 27017).db("networks")
    userCollection = db.collection("#{facebook_id}")
    
    puts userCollection.find().count()
    userCollection.find("d" => 1).each do |friend|
      friendCollection = db.collection("#{friend['_id']}")
      if friendCollection.find().count()>0
        #friendCollection.update("d"=>2, userCollection.find("d"=>1), true, true)
        puts friendCollection.find().count()
        puts friend["_id"]
      end
    end
end
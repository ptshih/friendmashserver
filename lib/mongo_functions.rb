require 'mongo'

# only populating first degree
def populateMongoNetwork
  
  db = Mongo::Connection.new("localhost", 27017).db("networks")
  
  coll = db.collection("masterNetwork")
  
  Network.where("degree=1").find_each(:batch_size => 5000) do |network|  
    #coll = db.collection(network['facebook_id'])
    #doc = {"_id"=> User.find_by_facebook_id(network['friend_id']).id, "d"=>network['degree']}
    
    doc = {"_id"=> network['friend_id'], "d"=>network['degree']}
    coll.insert(doc)    
  end
  
end

# populates 2nd degree
def populateExt(facebook_id)
    
end
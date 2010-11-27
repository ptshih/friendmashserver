class Name < ActiveRecord::Base
  #
  # Name.all.each do |n| n.delete end
  # Name.new.load_names
  # 
  # Used to load names from genders.txt into the Names table in DB
  # 
  def load_names
    f = File.open('genders.txt', "r") 
    f.each_line do |line|
      line = JSON.parse("[#{line}]")
      gender = (line[0] == 'm' ) ? 'male' : 'female'
      Name.create({:name=>line[1],:gender=>gender,:score=>line[2]})
    end
  end
end
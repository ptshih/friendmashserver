class Name < ActiveRecord::Base
end


def loadSomeNames
  f = File.open('genders.txt', "r") 
  f.each_line do |line|
    line = JSON.parse("[#{line}]")
    gender = (line[0] == 'm' )? 'male' : 'female'
    Name.create({:name=>line[1],:gender=>gender})
  end
end
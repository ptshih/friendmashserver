class Name < ActiveRecord::Base
end


def loadSomeNames
  f = File.open('genders.txt', "r") 
    f.each_line do |line|
      puts line
    end
end
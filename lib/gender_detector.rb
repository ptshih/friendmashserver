# This is the old gender detector
# This is UNUSED
def detectGender(name)
  html = HTTPClient.new.get_content("http://www.gpeters.com/names/baby-names.php?name=#{name}&button=Go")
  if html.include?("It's a boy")
    return 'male'
  elsif html.include?("It's a girl")
    return 'female'
  else
    return false
  end
end
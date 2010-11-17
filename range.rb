#!/usr/bin/ruby

score = 1500
low = 0
high = 0

ranges = [0, 1145, 1263, 1352, 1429, 1500, 1571, 1648, 1735, 1855, 3000]
found = 0
    
    ranges.each_with_index do |r,i|
      if score > r
        # keep going
	next
      else
	found = 1
        low = i - 1
        high = i
	break if found == 1
      end
    end

    puts ranges[low]
    puts ranges[high]

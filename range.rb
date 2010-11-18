#!/usr/bin/ruby


def distinct_range
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
end

def bounds(userScore, pop, popAverage, popSD, sampleSize)
  # k = (upperOrLower ? (1 * (sampleSize / pop)) : (-1 * (sampleSize / pop)))
  
  k_low = (-1 * (sampleSize / pop))
  k_high = (1 * (sampleSize / pop))
  
  array_returns_low = (600..2400).map { |i|
    (k_low + Math.erf((userScore-popAverage)/(popSD*(2.0**0.5))) - Math.erf((i-popAverage)/(popSD*(2.0**0.5)))).abs
  }
  
  array_returns_high = (600..2400).map { |i|
    (k_high + Math.erf((userScore-popAverage)/(popSD*(2.0**0.5))) - Math.erf((i-popAverage)/(popSD*(2.0**0.5)))).abs
  }

  return [(600..2400).map[array_returns_low.index(array_returns_low.min)], (600..2400).map[array_returns_high.index(array_returns_high.min)]]
end

puts bounds(1500.0, 1500.0, 1500.0, 282.0, 278.0)


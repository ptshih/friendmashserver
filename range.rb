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

def bounds(userScore, pop, popAverage, popSD, sampleSize, upperOrLower)
  k = (upperOrLower ? (1 * (sampleSize / pop)) : (-1 * (sampleSize / pop)))
  
  array_returns = (600..2400).map { |i|
    (k + Math.erf((userScore-popAverage)/(popSD**0.5)) - Math.erf((i-popAverage)/(popSD**0.5))).abs
  }

  # return array_returns.min.round
  return (600..2400).map[array_returns.min.round]
end

def factorial(n)
 if n == 0
   1
 else
   n * factorial(n-1)
 end
end

puts bounds(1600, 1000000, 1500, 224, 1000, true)


puts Math.erf(46.77)

x = Math.erf(46.77071732559853)

puts sprintf "%.10f", 46.77071732559853

puts Math::PI

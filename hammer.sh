#!/bin/bash
while [ 1 ]
do
curl -i -H "Accept: application/json" -H "X-FACEMASH-SECRET: omgwtfbbq" "http://facemash.heroku.com/mash/random/548430564?gender=male&recents=&mode=0"
sleep 0.1
done

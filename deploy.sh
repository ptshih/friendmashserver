#!/bin/bash
#
MSG=$1
: ${MSG:="quick deploy to heroku"}

echo "Deploying to Heroku with commit msg: $MSG"

git add .;
git commit -m '$MSG';
time git push heroku master --force;

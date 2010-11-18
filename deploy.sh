#!/bin/bash
#

# echo "Deploying to Heroku with commit msg: $MSG"

git add .;
git commit -m 'Quick desploy to Heroku';
time git push heroku master --force;

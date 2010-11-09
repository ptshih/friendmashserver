#!/bin/bash
#
git add *;
git commit -m 'quick deploy to heroku';
time git push heroku master --force;
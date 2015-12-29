#!/bin/bash
cd /app
bundle install
bundle exec rake db:create
bundle exec rake db:seed
#!/bin/bash
cd /app

echo "Bundling gems..."
bundle install --jobs 4 --retry 3

echo "Generating Spring binstubs..."
bundle exec spring binstub --all

echo "Clearing logs..."
bin/rake log:clear

# (Optional) Setup a database if your application requires one
# echo "Setting up new db if one doesn't exist..."
# If you're using ActiveRecord
# bin/rake db:version || { bundle exec rake db:setup; }
# If you're not using ActiveRecord (e.g. Mongo)
# bundle exec rake db:setup 

echo "Removing contents of tmp dirs..."
rm -rf tmp/unicorn.pid
bin/rake tmp:clear

echo "Setting up Foreman..."
gem install foreman
foreman start -f Procfile-dev
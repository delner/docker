FROM delner/nginx-unicorn-rails:1.8.0-2.3.0

# (Optional) Use gem data volume
# Create via: docker create -v /ruby_gems/2.3.0 --name gems-2.3.0 busybox
# ENV GEM_HOME /ruby_gems/2.3.0
# ENV PATH /ruby_gems/2.3.0/bin:$PATH

# (Optional) Set custom Nginx site configuration (if you have any)
# ADD config/nginx/production.conf /etc/nginx/sites-enabled/default

# Automatically start the web server
CMD gem install foreman && \
    bundle install && \
    bundle exec rake assets:precompile && \
    foreman start -f Procfile

EXPOSE 80
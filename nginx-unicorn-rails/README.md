# Nginx/Unicorn/Rails

Docker image for a Nginx/Unicorn/Rails deployment.

## What's included

* ruby, nginx, unicorn, rails, nodejs

## Usage

There are 4 suggested ways you can use this to setup a Rails application:

1. *Production only*: You just want to create some deployable images of your application.
2. *Development only*: You only want to use Docker to run a container to develop in locally.
3. *Development w/ docker-compose*: Same as above, but your application consists of multiple containers you want to configure together.
4. *Both development and production* (recommended): You want to develop locally, but have the option to build and deploy containers.

For each, you will need to copy/create a few files in your project. See the below sections for the one that fits your needs.

(It's highly recommended you use the gem cache for faster builds, and `docker-compose` configurations provided for development environments. Makes starting your application as simple as `docker-compose up`!)

### For a production environment only

1. (Optional & recommended) Create a data volume to store gems in. (To make `bundle install` much faster on `docker build`)

    ```
    docker create -v /ruby_gems/2.3.0 --name gems-2.3.0 busybox
    ```

2. Create `Dockerfile` in your project and add the following

    ```
    # Dockerfile
    FROM delner/nginx-unicorn-rails:1.8.0-2.3.0

    # (Optional) Use gem data volume
    # Create via: docker create -v /ruby_gems/2.3.0 --name gems-2.3.0 busybox
    # ENV GEM_HOME /ruby_gems/2.3.0
    # ENV PATH /ruby_gems/2.3.0/bin:$PATH

    # (Optional) Set custom Nginx site configuration (if you have any)
    # ADD config/nginx/production.conf /etc/nginx/sites-enabled/default

    # (Optional) Set custom Unicorn configuration (if you have any)
    # ADD config/unicorn/production.rb config/unicorn.rb

    # Automatically start the web server
    CMD gem install foreman && \
        bundle install && \
        bundle exec rake assets:precompile && \
        foreman start -f Procfile

    EXPOSE 80
    ```

3. Ensure your Gemfile has Unicorn:

    ```
    gem 'unicorn'
    ```

4. Build your project:

    ```
    # build your dockerfile
    $ docker build -t your/project .
    ```

5. Run your project

    ```
    # Run your container
    $ docker run -p 80:80 your/project
    # Or if you're using gem data volume
    $ docker run -p 80:80 --volumes-from gems-2.3.0 your/project
    ```

### For a development environment only

If you're wanting to run a development environment instead, here's how.

1. (Optional) Create a data volume to store gems in. (To make `bundle install` much faster on `docker build`)

    ```
    docker create -v /ruby_gems/2.3.0 --name gems-2.3.0 busybox
    ```

2. Create `Dockerfile` in your project and add the following

    ```
    FROM delner/nginx-unicorn-rails:1.8.0-2.3.0

    # (Optional) Use gem data volume
    # Created from: docker create -v /ruby_gems/2.3.0 --name gems-2.3.0 busybox
    # ENV GEM_HOME /ruby_gems/2.3.0
    # ENV PATH /ruby_gems/2.3.0/bin:$PATH

    # Set Nginx site configuration
    ADD config/nginx/development.conf /etc/nginx/sites-enabled/default

    # Automatically start the web server
    CMD ./script/start.sh

    EXPOSE 80
    ```

3. Create `config/nginx/development.conf` and add the code below. This is the Nginx config for the site. (Required because we need Nginx to request assets from Unicorn instead of /public when in development.)

    ```
    map $http_origin $cors_header {
      default     "";
      ~*((localhost|127\.0\.0\.1)(:\d+)*) "*";
    }

    upstream unicorn_server {
      server unix:/tmp/unicorn.sock fail_timeout=0;
    }

    server {
      listen 80 default deferred;
      root /app/public;

      try_files $uri @unicorn_server;
      location @unicorn_server {
        add_header 'Access-Control-Allow-Origin' $cors_header;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        #proxy_set_header X-Forwarded-Proto https; # if use ssl
        proxy_redirect off;
        proxy_pass http://unicorn_server;
      }

      error_page 500 502 503 504 /500.html;
      keepalive_timeout 10;
    }
    ```

4. Create `config/unicorn/development.rb` and add the code below. This is the Unicorn config file. (Required because when we mount our host's app directory, the packaged unicorn.rb will be wiped out.)

    ```
    app_dir = "/app"

    working_directory app_dir

    pid "#{app_dir}/tmp/unicorn.pid"

    stderr_path "#{app_dir}/log/unicorn.stderr.log"
    stdout_path "#{app_dir}/log/unicorn.stdout.log"

    worker_processes 1
    listen "/tmp/unicorn.sock", :backlog => 64
    timeout 30
    ```

5. Create `Procfile` and add the code below (Required because when we mount our host's app directory, the packaged Procfile will be wiped out.)

    ```
    web: bundle exec unicorn -c config/unicorn/development.rb
    nginx: /usr/sbin/nginx -c /etc/nginx/nginx.conf
    ```

6. Create `script/start.sh` and add the code below. This will be run every time the web server starts.

    ```
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
    foreman start -f Procfile
    ```

7. Ensure your Gemfile has both Spring and Unicorn:

    ```
    gem 'unicorn'
    gem 'spring'
    ```

8. Build your project

    ```
    # build your dockerfile
    $ docker build -t your/project .
    ```

9. Run your project

    ```
    # Run your container
    $ docker run -p 80:80 -v .:/app your/project
    # Or if you're using gem data volume
    $ docker run -p 80:80 -v .:/app --volumes-from gems-2.3.0 your/project
    ```

### For a development environment using docker-compose

Follow steps 2-7 from *For a development environment only* above first. Then all we need to do is add some docker-compose configuration.

(NOTE: You don't have to manually create the gem cache data volume via `docker create` if you want to use it with docker-compose, so skip that step too.)

1. Create `docker-compose.yml` and add the code below. Add any additional containers or configuration you require.

    ```
    # (Optional) Creates a gem cache data volume
    gems-2.3.0:
      image: busybox
      volumes:
        - /data/db
      command: /bin/true
    web:
      build: .
      dockerfile: Dockerfile
      command: ./script/start.sh
      # Mounts your host directory as the application, for live editing
      volumes:
        - .:/app
      # (Optional) Attaches gem cache data volume
      volumes_from:
      - gems-2.3.0
      ports:
        - "80:80"
    ```

2. Run your project

    ```
    # Run your application
    $ docker-compose up
    ```

### For both development & production environments

You'll want to create parallel configurations that don't conflict with one another. Development specific files should be renamed to `development` or have `-dev` suffixed to them.

1. Follow steps 1-7 from *For a development environment using docker-compose* above, but rename the following files:
    - `Dockerfile` --> `Dockerfile-dev`
    - `Procfile` --> `Procfile-dev`
2. Modify `script/start.sh` so that it reads `foreman start -f Procfile-dev`
3. Modify `docker-compose.yml` so that it reads `dockerfile: Dockerfile-dev`
4. Create a `Dockerfile` from step 2 of *For a production environment only* above, and 
5. Create a `Procfile` and add the code below.

    ```
    web: bundle exec unicorn -c config/unicorn/production.rb
    nginx: /usr/sbin/nginx -c /etc/nginx/nginx.conf
    ```
5. Copy `config/unicorn/development.rb` to `config/unicorn/production.rb` and make any necessary modifications.
6. (Optional) If you have production specific Nginx configuration, enable `ADD config/nginx/production.conf` in your `Dockerfile` and create a `config/nginx/production.conf` file with your Nginx configuration.
7. Build & run your project
  
    ```
    # PRODUCTION:
    $ docker build -t your/project .
    $ docker run -p 80:80 your/project
    # Or if you're using gem data volume
    $ docker run -p 80:80 --volumes-from gems-2.3.0 your/project
    # DEVELOPMENT:
    $ docker-compose up
    ```

## How it works

The base image contains Nginx and Unicorn, which are configured with some production defaults.

Your web request passes through the port binding on 'localhost:80' to the container's Nginx server. That server then checks for any URI matches (via `location`) and serves any matching files, but otherwise 404s. This is typical for handling assets in production, so we can use Nginx to serve static files directly instead of using Unicorn.

If the request doesn't explicitly match any location, it forwards off the request to Unicorn via socks, so that it might be able to generate a response. This is the most common path for dynamic requests that can only be fulfilled by Rails, or for assets in development (since they are otherwise not available in the public folder.) Unicorn kicks off the request to one of its workers, which routes the request through your Rails application.

Some important notes:

 - Data on this image is ephemeral: it will revert state when the container stops, and any changes will be lost. This makes it particularly tricky for databases and gem bundles, and can really make container startup & building painfully slow, since `bundle install can take forever to run. To circumvent this issue, this README has some suggested configuration for using data volumes, which can persist data between container lives, saving lots of startup time.
 - Sometimes the `tmp/unicorn.pid` file can become stale and prevent a container from running between restarts. Similarly, some cache data in the `tmp` directly can cause some permission errors for Rails. This is why the `start.sh` script removes these files.
 - This configuration is compatible with deployments that utilize databases and environment variables, but they aren't strictly covered here.

## Additional resources

Based originally on https://github.com/seapy/dockerfiles/tree/master/rails-nginx-unicorn

Modified based on some interesting features from other examples around the web:

 - Docker volumes: https://docs.docker.com/v1.8/userguide/dockervolumes/
 - Docker compose + Rails: https://docs.docker.com/compose/rails/
 - Docker + Chef: http://growingdevs.com/your-first-docker-rails-deployment.html
 - Gem cache: http://www.atlashealth.com/blog/2014/09/persistent-ruby-gems-docker-container/#.VoIXzHUrJbg
 - Docker compose + MongoDB: http://www.diogogmt.com/running-mongodb-with-docker-and-compose/
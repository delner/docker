FROM ubuntu:14.04.3
MAINTAINER David Elner <david@davidelner.com>

RUN apt-get update

# Install ruby dependencies
RUN apt-get install -y wget curl \
    build-essential git git-core \
    zlib1g-dev libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt1-dev

RUN apt-get update

# Install Ruby 2.3
RUN cd /tmp &&\
  wget -O ruby-2.3.0.tar.gz https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.0.tar.gz &&\
  tar -xzvf ruby-2.3.0.tar.gz &&\
  cd ruby-2.3.0/ &&\
  ./configure &&\
  make &&\
  make install &&\
  cd /tmp &&\
  rm -rf ruby-2.3.0 &&\
  rm -rf ruby-2.3.0.tar.gz

  # Add Ruby binaries to $PATH
ENV PATH /opt/rubies/ruby-2.3.0/bin:$PATH

# Add options to gemrc
RUN echo "gem: --no-document" > ~/.gemrc

# Install bundler
RUN gem install bundler
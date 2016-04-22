FROM dit4c/dit4c-container-base:debian
MAINTAINER Tim Dettrick <t.dettrick@uq.edu.au>

RUN apt-get update && \
  apt-get install -y \
    runit build-essential git zlib1g-dev libyaml-dev libssl-dev libgdbm-dev \
    libreadline-dev libncurses5-dev libffi-dev curl openssh-server \
    checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev \
    logrotate python-docutils pkg-config cmake nodejs graphviz && \
  apt-get clean

# Install Ruby
RUN mkdir -p /tmp/ruby && cd /tmp/ruby && \
  curl -Ls https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.0.tar.gz | tar xz && \
  cd ruby-2.3.0 && \
  ./configure --disable-install-rdoc && \
  make -j $(nproc) && \
  make install && \
  cd /tmp && rm -rf /tmp/ruby

# Install Ruby Gems
RUN gem install rake bundler foreman --no-ri --no-rdoc

# Install MySQL
RUN apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client libmysqlclient-dev && \
  apt-get clean

ENV LC_ALL=C.UTF-8

RUN adduser --disabled-login --gecos 'Huginn' huginn && \
  cd /home/huginn && \
  sudo -u huginn -H git clone https://github.com/cantino/huginn.git -b master huginn && \
  cd /home/huginn/huginn && \
  sudo -u huginn -H cp .env.example .env && \
  sudo -u huginn mkdir -p log tmp/pids tmp/sockets && \
  sudo chown -R huginn log/ tmp/ && \
  sudo chmod -R u+rwX,go-w log/ tmp/ && \
  sudo -u huginn -H chmod o-rwx .env && \
  sudo -u huginn -H cp config/unicorn.rb.example config/unicorn.rb
RUN cd /home/huginn/huginn && \
  sudo -u huginn -H bundle install --deployment --without development test
RUN cd /home/huginn/huginn && \
  sed -i -e 's/DATABASE_PASSWORD=""/DATABASE_PASSWORD=password/' .env && \
  sed -i -e 's/# RAILS_ENV=production/RAILS_ENV=production/' .env && \
  mkdir -p /var/log/mysql && \
  (/usr/bin/mysqld_safe &) && \
  PID=$? && \
  sleep 5 && \
  echo "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('password');" | mysql -u root && \
  sudo -u huginn -E -H bundle exec rake db:create RAILS_ENV=production && \
  sudo -u huginn -E -H bundle exec rake db:migrate RAILS_ENV=production && \
  sudo -u huginn -E -H bundle exec rake db:seed RAILS_ENV=production SEED_USERNAME=researcher SEED_PASSWORD=researcher && \
  sudo -u huginn -E -H bundle exec rake assets:precompile RAILS_ENV=production

ADD /etc /etc

RUN rm /etc/mysql/conf.d/mysqld_safe_syslog.cnf && \
  mkdir -p /var/log/mysql && \
  chown mysql:mysql /var/log/mysql && \
  echo "[mysqld_safe]\nlog-error=/var/log/mysql/error.log" > /etc/mysql/conf.d/mysqld_safe_logging.cnf


############################################
# This Dockerfile builds a docker image
# suitable to boot a CBRAIN BrainPortal
# where tests can be run. It is meant
# to be run within a Travis Continuous
# Integration virtual machine,
# although invoking its entry point manually
# from docker is also a possibility.
############################################

FROM centos:latest



#####################################
# Package updates and installations #
#####################################

# Note: keep the package list alphabetically
#       ordered to facilitate parsing

RUN yum update -y
RUN yum install -y \
      autoconf \
      automake \
      make \
      bzip2 \
      bison \
      gcc-c++ \
      git \
      glibc-devel \
      glibc-headers \
      gpg \
      libffi-devel \
      libmysqlclient-dev \
      libtool \
      libxml2 \
      libxml2-devel \
      libyaml-devel \
      mariadb-devel \
      mariadb-server \
      openssl-devel \
      patch \
      readline-devel \
      sqlite-devel \
      zlib-devel \
      which \
      wget

# The following UID and GID are chosen
# to match what is usually the unprivileged user
# that runs inside the Travis CI virtual machines,
# but that should not make much difference.
RUN groupadd -g 500        cbrain
RUN useradd  -u 500 -g 500 cbrain

# Environment variables for the MYSQL DB
ENV MYSQL_ROOT_PASSWORD="my-secret-pw" MYSQL_USER="cb_user" MYSQL_DATABASE="cb_db_test" MYSQL_PASSWORD="cbpw12345"



#############################################
# MySQL server installation and configuration
#############################################

RUN mysql_install_db
RUN mkdir -p /var/lib/mysql /var/run/mysqld
RUN chown -R mysql:mysql /var/lib/mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld
RUN rm -f /var/lib/mysql/aria_log_control

RUN mysqld_safe & sleep 3 && \
    /usr/bin/mysqladmin -u root password "$MYSQL_ROOT_PASSWORD"

RUN mysqld_safe & sleep 3 && \
    /usr/bin/mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "create database $MYSQL_DATABASE;"

RUN mysqld_safe & sleep 3 && \
    /usr/bin/mysql -u root --password="$MYSQL_ROOT_PASSWORD" -e "grant all on $MYSQL_DATABASE.* to '$MYSQL_USER'@'localhost' identified by '$MYSQL_PASSWORD';"



#############################
# Ruby and rvm installation #
#############################

USER cbrain

ENV RUBY_VERSION=2.6.3

RUN cd $HOME && curl -sSL https://rvm.io/mpapis.asc | gpg2 --import -
RUN cd $HOME && curl -sSL https://rvm.io/pkuczynski.asc | gpg2 --import -

RUN cd $HOME && curl -sSL https://get.rvm.io | bash -s stable

RUN cd $HOME && echo "source $HOME/.rvm/scripts/rvm" >> $HOME/.bashrc

RUN bash --login -c 'rvm install $RUBY_VERSION --autolibs=read'

RUN bash --login -c 'rvm --default $RUBY_VERSION'



################################
# Rails application bundling   #
################################

# These four statements is a way for the
# people building the container to specify
# variations on what base CBRAIN installation
# to use.
ARG CBRAIN_REPO=https://github.com/aces/cbrain.git
ARG CBRAIN_BRANCH=dev
ENV CBRAIN_REPO=$CBRAIN_REPO
ENV CBRAIN_BRANCH=$CBRAIN_BRANCH

# Edit manually the following line to have your docker installation
# skip its cache of the previous container build, if necessary.
# Just having a different commit number in the echo statement will do.
# This can be necessary if you know that the code on the GitHub
# repo has changed since that last build.
RUN echo Force install using CBRAIN at commit d4eca710772

# Extract initial CBRAIN source (will be replaced at test time)
# but having an initial installation speeds up bundling,
# migrations, etc.
# I would use --single-branch in the git clone command below, but
# it seems not all git packages support it.
RUN cd $HOME && \
    git clone --branch "$CBRAIN_BRANCH" --depth 2 "$CBRAIN_REPO" cbrain_base

# Install and configure the portal
ENV RAILS_ENV=test

RUN bash --login -c 'cd $HOME/cbrain_base/BrainPortal && gem install bundler'

RUN bash --login -c 'cd $HOME/cbrain_base/BrainPortal && bundle install'

RUN bash --login -c 'cd $HOME/cbrain_base/Bourreau && bundle install'

RUN bash --login -c 'cd $HOME/cbrain_base/BrainPortal && cd $(bundle show sys-proctable) && rake install'

COPY ./templates/database.yml.TEST     /home/cbrain/cbrain_base/BrainPortal/config/database.yml

COPY ./templates/config_portal.rb.TEST /home/cbrain/cbrain_base/BrainPortal/config/initializers/config_portal.rb

# Seed the DB
USER root

RUN  chown cbrain /home/cbrain/cbrain_base/BrainPortal/config/database.yml && \
     chown cbrain /home/cbrain/cbrain_base/BrainPortal/config/initializers/config_portal.rb

RUN su -c "bash --login -c 'cd \$HOME/cbrain_base/BrainPortal && rake cbrain:plugins:install:plugins'" cbrain

RUN mysqld_safe & sleep 2 && \
    su -c "bash --login -c 'cd \$HOME/cbrain_base/BrainPortal && rake db:schema:load'" cbrain

RUN mysqld_safe & sleep 2 && \
    su -c "bash --login -c 'cd \$HOME/cbrain_base/BrainPortal && rake db:seed'" cbrain

RUN mysqld_safe & sleep 2 && \
    su -c "bash --login -c 'cd \$HOME/cbrain_base/BrainPortal && rake db:seed:test:bourreau'" cbrain

RUN mysqld_safe & sleep 2 && \
    su -c "bash --login -c 'cd \$HOME/cbrain_base/BrainPortal && rake db:sanity:check'" cbrain



########################################################
# Cleanup files to make the image as small as possible #
########################################################

USER cbrain

RUN bash --login -c 'rvm cleanup all'

USER root

RUN yum clean all

# Not sure if next line won't interfere with future bundle updates...
# but then it saves just a few dozen megabytes.
RUN rm -rf /home/cbrain/.rvm/gems/ruby*/bundler/gems/*/.git



#########################
# Ports and entry point #
#########################

# This command will copy the code freshly extracted by travis
# and perform the rest of the setup needed to run the tests
# (migrate the DB, run rake tasks, run rspec); the path
# /home/cbrain/cbrain_travis is a mounted volume from the
# VM side.
CMD [ "/home/cbrain/cbrain_travis/Travis/bootstrap.sh" ]

###########
# Volumes #
###########
#
# Only one volume is needed, it is Travis CI's own
# copy of the cbrain project to be tested.
#
# Note that this is distinct from
#
#   /home/cbrain/cbrain_base
#
# which is where we did the initial installation here
# in this image, as a way to speed up the tests.

VOLUME /home/cbrain/cbrain_travis


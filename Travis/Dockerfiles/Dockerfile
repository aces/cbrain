FROM centos:6

#####################################
# Package updates and installations #
#####################################

# Note: keep the package list alphabetically
#       ordered to facilitate parsing

RUN yum update -y
RUN yum install -y \
      autoconf \
      automake \
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
      mysql-devel \
      openssl-devel \
      patch \
      readline-devel \
      sqlite-devel \
      zlib-devel \
      wget
RUN   groupadd -g 500 cbrain
RUN   useradd  -u 500 -g 500 cbrain

##########################
# Dockerize installation #
##########################

# Dockerize is used in run.sh to edit template configuration files and
# to wait for the DB to be started before starting the portal

ENV DOCKERIZE_VERSION v0.2.0
RUN wget https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz && \
    tar -C /usr/local/bin -xzvf dockerize-linux-amd64-$DOCKERIZE_VERSION.tar.gz

#####################
# Ruby installation #
#####################

USER cbrain

ENV RUBY_VERSION=2.2.0

RUN cd $HOME && \
    curl -sSL https://rvm.io/mpapis.asc | gpg2 --import - && \
    curl -sSL https://get.rvm.io | bash -s stable && \
    echo source ${HOME}/.profile >> ${HOME}/.bashrc && \
    source /home/cbrain/.bashrc && \
    rvm install $RUBY_VERSION && \
    rvm --default $RUBY_VERSION && \
    echo source "\$(rvm ${RUBY_VERSION} do rvm env --path)" >> ${HOME}/.bashrc && \
    source /home/cbrain/.bashrc && \
    rvm info && \
    gem install bundler
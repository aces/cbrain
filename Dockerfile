FROM centos:6

RUN yum update -y  && yum install -y \
      gpg \
      libyaml-devel \
      glibc-headers \
      autoconf \
      gcc-c++ \
      glibc-devel \
      readline-devel \
      zlib-devel \
      libffi-devel \
      openssl-devel \
      automake \
      libtool \
      bison \
      sqlite-devel \
      git \
      patch \
      libxml2 \
      libxml2-devel \
      mysql-devel \
      libmysqlclient-dev

RUN useradd cbrain
COPY . /home/cbrain/cbrain
RUN chown cbrain:cbrain -R /home/cbrain/cbrain
USER cbrain

RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN cd $HOME && \
    \curl -sSL https://get.rvm.io | bash -s stable

RUN /bin/bash -c "source $HOME/.rvm/scripts/rvm; rvm install 2.2.0; rvm --default 2.2.0"

ENV PATH $PATH:/home/cbrain/.rvm/rubies/ruby-2.2.0/bin
RUN gem install bundler

RUN cd $HOME/cbrain/BrainPortal    && \
    bundle install                 && \
    cd `bundle show sys-proctable` && \
    rake install

RUN cd $HOME/cbrain/BrainPortal    && \
    rake cbrain:plugins:install:all

RUN cd $HOME/cbrain/Bourreau       && \
    bundle install

RUN cd $HOME/cbrain/BrainPortal    && \
    rake cbrain:plugins:install:plugins

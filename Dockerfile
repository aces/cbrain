FROM centos:5

RUN yum update  -y 
RUN yum install -y wget
RUN wget http://download.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
RUN rpm -ivh epel-release-5-4.noarch.rpm

RUN yum update -y  && yum install -y \
        git openssh \
        mariadb-devel \
        mariadb  \
        libyaml-devel \
        glibc-headers \
        autoconf \
        gcc-c++ \
        glibc-devel \
        patch \
        readline-devel \
        libffi-devel \
        make \
        bzip2 \
        automake \
        libtool \
        bison \
        sqlite-devel \
        libxml2 \
        libxml2-devel \
        libxslt \
        gpg \
        which \
       openssl-devel \
       mysql-devel

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
    bundle install                 && \
    rake cbrain:plugins:install:plugins

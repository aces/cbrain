FROM ruby:2.6.3

RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -yq dist-upgrade

EXPOSE 3000

WORKDIR /BrainPortal
COPY ./BrainPortal /BrainPortal

RUN bundle install

CMD ["rails", "server", "-b", "0.0.0.0"]

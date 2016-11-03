#!/bin/bash -e

#####################
# Utility functions #
#####################

# Runs a simple query to make sure we can access the DB.
function check_connection {
    mysql ${MYSQL_OPTIONS} -e "show databases;" &>/dev/null
}

###############
# Main script #
###############
id
source /home/cbrain/.bashrc

source /home/cbrain/cbrain/Travis/entry_points/functions.sh

# Edits DB configuration file from template
dockerize -template $HOME/cbrain/Travis/templates/database.yml.TEMPLATE:$HOME/cbrain/BrainPortal/config/database.yml                      || die "Cannot edit DB configuration file"

# Edits portal name from template
dockerize -template $HOME/cbrain/Travis/templates/config_portal.rb.TEMPLATE:$HOME/cbrain/BrainPortal/config/initializers/config_portal.rb || die "Cannot edit CBRAIN configuration file"

# Edits data provider configuration from template
dockerize -template $HOME/cbrain/Travis/templates/create_dp.rb.TEMPLATE:$HOME/cbrain/Travis/init_portal/create_dp.rb                      || die "Cannot edit Create DP configuration file"

# Edits bourreau configuration from template
dockerize -template $HOME/cbrain/Travis/templates/create_bourreau.rb.TEMPLATE:$HOME/cbrain/Travis/init_portal/create_bourreau.rb          || die "Cannot edit Create Bourreau configuration file"

# Waits for DB to be available
dockerize -wait tcp://${MYSQL_HOST}:${MYSQL_PORT} -timeout 90s || die "Cannot wait for mysql:3306 to be up or timeout was reached"

export MYSQL_OPTIONS="-h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} --password=${MYSQL_PASSWORD}"
while ! check_connection
do
  echo "$(date) - still trying to connect to the database"
  sleep 1
done

cd $HOME/cbrain/BrainPortal     || die "Cannot cd to BrainPortal directory"
export RAILS_ENV=test
bundle                          || die "Cannot bundle Rails application"
bundle install                  || die "Cannot bundle install"
rake cbrain:plugins:install:all
rake cbrain:plugins:install:all || die "Cannot install cbrain:plugins"
rake db:schema:load             || die "Cannot load DB schema"
rake db:seed                    || die "Cannot seed DB"
rake db:sanity:check            || die "Cannot sanity check DB"
rspec spec                      || die "Failed running rspec"
#!/bin/bash --login

set -a # bash will exit immediately if any command returns a code other than 0

#####################
# Utility functions #
#####################

# Prints a message and exits with a non-zero code.
function die {
    echo Fatal: "$*"
    exit 2
}

###############
# Main script #
###############

# Install the code base to be tested
cd $HOME
test -e "cbrain_test" && ls -la && die "Oh oh, some directory 'cbrain_test' is in the way"
cp -p -r cbrain_travis cbrain_test || die "Cannot copy the cbrain code base to 'cbrain_test'..."

# Edits DB configuration file from template
dockerize -template $HOME/cbrain_test/Travis/templates/database.yml.TEMPLATE:$HOME/cbrain_test/BrainPortal/config/database.yml                      || die "Cannot edit DB configuration file"

# Edits portal name from template
dockerize -template $HOME/cbrain_test/Travis/templates/config_portal.rb.TEMPLATE:$HOME/cbrain_test/BrainPortal/config/initializers/config_portal.rb || die "Cannot edit CBRAIN configuration file"

# Make sure RVM is loaded
source /home/cbrain/.bashrc

# Go to the new code to test
cd $HOME/cbrain_test/BrainPortal  || die "Cannot cd to BrainPortal directory"

# Prep all that needs to be prepared. With a bit of luck, bundle install
# will be quite quick given that when building the docker image we already
# ran it once in ~/cbrain_base.
export RAILS_ENV=test
bundle install
rake cbrain:plugins:install:plugins || die "Cannot install cbrain:plugins"

# Waits for DB to be available
dockerize -wait tcp://${MYSQL_HOST}:${MYSQL_PORT} -timeout 90s || die "Cannot wait for mysql:3306 to be up or timeout was reached"

# Runs a simple query to make sure we can access the DB.
mysql_options="-h ${MYSQL_HOST} -P ${MYSQL_PORT} -u ${MYSQL_USER} --password=${MYSQL_PASSWORD}"
for cnt in 1 2 3 4 5 6 7 8 9 10 waytoolong
do
  echo "Attempt #$cnt : $(date) - trying to connect to the database"
  mysql $mysql_options -e 'select "Yippee, database is now accessible";' && break
  test "X$cnt" = "Xwaytoolong" && die "Cannot wait for DB any longer..."
  sleep 3
done

# Prep steps that necessitates the DB to be ready.
rake db:schema:load   || die "Cannot load DB schema"
rake db:seed          || die "Cannot seed DB"
rake db:sanity:check  || die "Cannot sanity check DB"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
rspec spec            || die "Failed running rspec"


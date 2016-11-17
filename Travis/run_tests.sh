#!/bin/bash --login

set -e # bash will exit immediately if any command returns a code other than 0

#####################
# Utility functions #
#####################

# Prints a message and exits with a non-zero code.
function die {
    echo Fatal: "$*"
    exit 5
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
export RAILS_ENV=test



# ------------------------------
# Portal-Side Initializations
# ------------------------------

# Go to the new code to test
cd $HOME/cbrain_test/BrainPortal    || die "Cannot cd to BrainPortal directory"

# Prep all that needs to be prepared. With a bit of luck, bundle install
# will be quite quick given that when building the docker image we already
# ran it once in ~/cbrain_base.
bundle install                      || die "Cannot bundle gems for the BrainPortal"
rake cbrain:plugins:install:plugins || die "Cannot install cbrain:plugins" # works for Bourreau too



# ------------------------------
# Bourreau-Side Initializations
# ------------------------------

# Go to the new code to test
cd $HOME/cbrain_test/Bourreau       || die "Cannot cd to Bourreau directory"
bundle install                      || die "Cannot bundle gems for the Bourreau"



# ------------------------------
# Wait for DB
# ------------------------------

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



# ------------------------------
# Seed the DB
# ------------------------------

# Prep steps that necessitates the DB to be ready.
cd $HOME/cbrain_test/BrainPortal || die "Cannot cd to BrainPortal directory"
rake "db:schema:load"        || die "Cannot load DB schema"
rake "db:seed"               || die "Cannot seed DB for BrainPortal"
rake "db:seed:test:bourreau" || die "Cannot seed the DB for Bourreau"
rake "db:sanity:check"       || die "Cannot sanity check DB"

# In order to always run both rspec commands, we save the failures in a string.
fail_portal=""
fail_bourreau=""


# ------------------------------
# Portal-Side Testing
# ------------------------------
cd $HOME/cbrain_test/BrainPortal || die "Cannot cd to BrainPortal directory"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
rspec spec                       || fail_portal="rspec on BrainPortal failed with return code $?"



# ------------------------------
# Bourreau-Side Testing
# ------------------------------
cd $HOME/cbrain_test/Bourreau    || die "Cannot cd to Bourreau directory"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
# -> NOTE FIXME TODO : hardcoded 'spec/boutiques' for <-
# -> the moment because no other test files work on Bourreau. <-
rspec spec/boutiques             || fail_bourreau="rspec on Bourreau failed with return code $?"



# ------------------------------
# Return status of both rspec
# ------------------------------
test -z "$fail_portal$fail_bourreau" && exit 0  # Pangloss
echo ""
echo "**** rspec commands failures summary ****"
test -n "$fail_portal"   && echo "$fail_portal"
test -n "$fail_bourreau" && echo "$fail_bourreau"
echo "**** ------------------------------- ****"
echo ""
exit 2


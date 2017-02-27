#!/bin/bash --login

# This script is run as a 'cbrain' user within a prepared Docker container
# presumably built beforehand with "build_container.sh"

set -e # bash will exit immediately if any command returns a code other than 0

# Terminal colors, using ANSI sequences.
RED='\033[31m'
YELLOW='\033[33m'
BLUE='\033[34m'
NC='\033[0m'

printf "${YELLOW}Rails code initialization starting at %s ${NC}\n" "$(date '+%F %T')"

# Three copies of the CBRAIN code base:
cb_base="$HOME/cbrain_base"      # pre-installed and configured in docker container, for efficiency
cb_travis="$HOME/cbrain_travis"  # docker mount point, where the code to be tested is
cb_test="$HOME/cbrain_test"      # local copy of cbrain_travis where we run the tests

#####################
# Utility functions #
#####################

# Prints a message and exits with a non-zero code.
function die {
    printf "${RED}Fatal: ";echo -n "$*";printf "${NC}\n"
    exit 5
}

# Returns a checksum for the list of files
# and directories under the directory given in argument.
# Does not check the file contents, only the names
# of all the entries.
function dir_list_cksum {
  pushd "$1" >/dev/null
  find . -print | sort | md5sum | cut -c1-32
  popd >/dev/null
}

###############
# Main script #
###############

# Install the code base to be tested
cd $HOME

test -e "$cb_test" && ls -la && die "Oh oh, some directory '$cb_test' is in the way..."
cp -p -r "$cb_travis" "$cb_test" || die "Cannot copy the cbrain code base to '$cb_test'..."

# Copy DB configuration file from the docker original install
cp -p "$cb_base"/BrainPortal/config/database.yml \
      "$cb_test"/BrainPortal/config/database.yml || die "Cannot copy DB configuration file"

# Copy CBRAIN configuration file from the docker original install
cp -p "$cb_base"/BrainPortal/config/initializers/config_portal.rb \
      "$cb_test"/BrainPortal/config/initializers/config_portal.rb || die "Cannot copy CBRAIN configuration file"

# Copy the symlinks for installed plugins
rsync -a --ignore-existing \
      "$cb_base"/BrainPortal/cbrain_plugins/installed-plugins/ \
      "$cb_test"/BrainPortal/cbrain_plugins/installed-plugins

# Make sure RVM is loaded
source /home/cbrain/.bashrc
export RAILS_ENV=test



# ------------------------------
# Portal-Side Re-Initializations
# ------------------------------

# Go to the new code to test
cd $cb_test/BrainPortal || die "Cannot cd to BrainPortal directory"

# Prep all that needs to be prepared. With a bit of luck, bundle install
# will be quite quick given that when building the docker image we already
# ran it once in ~/cbrain_base.

# Only bundle the gems if the Gemfile has changed
if ! cmp -s "$cb_base/BrainPortal/Gemfile" \
            "$cb_test/BrainPortal/Gemfile" ; then
  printf "${YELLOW}Running Bundler on BrainPortal side.${NC}\n"
  bundle install || die "Cannot bundle gems for the BrainPortal"
else
  printf "${BLUE}No need to run the Bundler on BrainPortal side, yippee!${NC}\n"
  cp -p "$cb_base/BrainPortal/Gemfile.lock" \
        "$cb_test/BrainPortal/Gemfile.lock"
fi

# Only install the plugins if the list of plugins files has changed.
if test $(dir_list_cksum "$cb_base/BrainPortal/cbrain_plugins") != \
        $(dir_list_cksum "$cb_test/BrainPortal/cbrain_plugins") ; then
  printf "${YELLOW}Installing plugins symbolic links.${NC}\n"
  rake cbrain:plugins:install:plugins || die "Cannot install cbrain:plugins" # works for Bourreau too
else
  printf "${BLUE}No need to install the plugins symbolic links, yippee!${NC}\n"
fi



# ------------------------------
# Bourreau-Side Initializations
# ------------------------------

# Go to the new code to test
cd $cb_test/Bourreau || die "Cannot cd to Bourreau directory"

# Only bundle the gems if the Gemfile has changed
if ! cmp -s "$cb_base/Bourreau/Gemfile" \
            "$cb_test/Bourreau/Gemfile" ; then
  printf "${YELLOW}Running Bundler on Bourreau side.${NC}\n"
  bundle install || die "Cannot bundle gems for the Bourreau"
else
  printf "${BLUE}No need to run the Bundler on Bourreau side, yippee!${NC}\n"
  cp -p "$cb_base/Bourreau/Gemfile.lock" \
        "$cb_test/Bourreau/Gemfile.lock"
fi



# ------------------------------
# Bring the DB up to date
# ------------------------------

# Prep steps that necessitates the DB to be ready.
cd $cb_test/BrainPortal || die "Cannot cd to BrainPortal directory"

# Only migrate if the list of migration files have changed.
if test $(dir_list_cksum "$cb_base/BrainPortal/db/migrate") != \
        $(dir_list_cksum "$cb_test/BrainPortal/db/migrate") ; then
  printf "${YELLOW}Running the database migrations.${NC}\n"
  rake "db:migrate" || die "Cannot migrate the DB"
else
  printf "${BLUE}No need to migrate the DB, yippee!${NC}\n"
fi

# This cannot be avoided.
printf "${YELLOW}Running the database sanity checks.${NC}\n"
rake "db:sanity:check" || die "Cannot sanity check DB"



# ------------------------------
# Finally, run the tests!
# ------------------------------
# In order to always run both rspec commands, we save the failures in a string.
fail_portal=""
fail_bourreau=""

# ------------------------------
# Portal-Side Testing
# ------------------------------
cd $cb_test/BrainPortal || die "Cannot cd to BrainPortal directory"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
printf "${BLUE}Running rspec on BrainPortal side.${NC}\n"
rspec spec || fail_portal="rspec on BrainPortal failed with return code $?"
#CBRAIN_FAILTEST=1 rspec spec/modules/travis_ci_spec.rb || fail_portal="rspec on BrainPortal failed with return code $?"



# ------------------------------
# Bourreau-Side Testing
# ------------------------------
cd $cb_test/Bourreau || die "Cannot cd to Bourreau directory"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
# -> NOTE FIXME TODO : hardcoded 'spec/boutiques' for <-
# -> the moment because no other test files work on Bourreau. <-
printf "${BLUE}Running rspec on Bourreau side.${NC}\n"
rspec spec/boutiques || fail_bourreau="rspec on Bourreau failed with return code $?"



# ------------------------------
# Return status of both rspec
# ------------------------------
test -z "$fail_portal$fail_bourreau" && exit 0  # Pangloss
echo ""
printf "${YELLOW}**** rspec commands failures summary ****${NC}\n"
test -n "$fail_portal"   && printf "${RED}$fail_portal${NC}\n"
test -n "$fail_bourreau" && printf "${RED}$fail_bourreau${NC}\n"
printf "${YELLOW}**** ------------------------------- ****${NC}\n"
echo ""
exit 2


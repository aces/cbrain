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
# Report Version Numbers
# ------------------------------
echo ""
printf "${YELLOW}Versions of CBRAIN code base installed:${NC}\n"

cd $cb_base/BrainPortal || die "Cannot cd to base BrainPortal directory"
printf "${BLUE}Container BASE CBRAIN:${NC} "
git log --date=iso -n 1 --pretty="%h by %an at %ad, %s"

cd $cb_test/BrainPortal || die "Cannot cd to test BrainPortal directory"
printf "${BLUE}Travis CI TEST CBRAIN:${NC} "
git log --date=iso -n 1 --pretty="%h by %an at %ad, %s"
printf "${BLUE}Travis CI REV CBRAIN:${NC}  "; script/show_cbrain_rev -z

echo ""



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
  rake "cbrain:plugins:install:plugins" || die "Cannot install cbrain:plugins" # works for Bourreau too
else
  printf "${BLUE}No need to install the plugins symbolic links, yippee!${NC}\n"
fi



# --------------------------------
# Bourreau-Side Re-Initializations
# --------------------------------

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



# -------------------------------
# Show TEST environment variables
# -------------------------------
# These environment variable allow the
# user to skip over some test stages,
# or make the API tests more verbose.
printf "${BLUE}Environment variables for this test session:${NC}\n"
echo   ""
echo   "General control:"
printf "${YELLOW}CBRAIN_SKIP_TEST_STAGES${NC}        = '${CBRAIN_SKIP_TEST_STAGES:=unset}'\n"
printf "Possible values: \"RspecPortal,RspecBourreau,CurlAPI,GemAPI\"\n"
echo   ""
echo   "API test control:"
printf "${YELLOW}CBRAIN_CURL_TEST_VERBOSE_LEVEL${NC} = '${CBRAIN_CURL_TEST_VERBOSE_LEVEL:=1}'\n"
printf "${YELLOW}CBRAIN_CURL_TEST_FILTER${NC}        = '${CBRAIN_CURL_TEST_FILTER}'\n"
printf "${YELLOW}CBRAIN_GEM_TEST_VERBOSE_LEVEL${NC}  = '${CBRAIN_GEM_TEST_VERBOSE_LEVEL:=1}'\n"
printf "${YELLOW}CBRAIN_GEM_TEST_FILTER${NC}         = '${CBRAIN_GEM_TEST_FILTER}'\n"
echo   ""



# ------------------------------
# Finally, run the tests!
# ------------------------------
# We save the failures of the main test commands in strings.
# That way we run them all and report everything at the end.
fail_portal=""
fail_bourreau=""
fail_api_curl=""
fail_api_ruby=""



# ------------------------------
# Portal-Side Testing
# ------------------------------
cd $cb_test/BrainPortal || die "Cannot cd to BrainPortal directory"

# Eventually, it would be nice if from a ENV variable set in Travis,
# we could run only a subset of the tests.
printf "${BLUE}Running rspec on BrainPortal side.${NC}\n"
if echo "X$CBRAIN_SKIP_TEST_STAGES" | grep -q 'RspecPortal' >/dev/null ; then
  printf "${YELLOW} -> Skipped by request from env CBRAIN_SKIP_TEST_STAGES${NC}\n"
else
  rspec spec || fail_portal="rspec on BrainPortal failed with return code $?"
fi
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
if echo "X$CBRAIN_SKIP_TEST_STAGES" | grep -q 'RspecBourreau' >/dev/null ; then
  printf "${YELLOW} -> Skipped by request from env CBRAIN_SKIP_TEST_STAGES${NC}\n"
else
  rspec spec/boutiques || fail_bourreau="rspec on Bourreau failed with return code $?"
fi



# ------------------------------
# Testing of API (curl)
# ------------------------------
printf "${BLUE}Running API tests with curl.${NC}\n"
if echo "X$CBRAIN_SKIP_TEST_STAGES" | grep -q 'CurlAPI' >/dev/null ; then
  printf "${YELLOW} -> Skipped by request from env CBRAIN_SKIP_TEST_STAGES${NC}\n"
else
  cd $cb_test/BrainPortal            || die "Cannot cd to BrainPortal directory"
  rake "db:seed:test:api" >/dev/null || die "Cannot re-seed the DB for API testing"
  rails server puma -p 3000 -d       || die "Cannot start local puma server?"
  cd test_api                        || die "Cannot cd to test_api directory?"
  sleep 5 # must wait a bit for puma to be ready
  perl curl_req_tester.pl                 \
    -h localhost                          \
    -p 3000                               \
    -s http                               \
    -v"${CBRAIN_CURL_TEST_VERBOSE_LEVEL}" \
    -R                                    \
    ${CBRAIN_CURL_TEST_FILTER}            \
    || fail_api_curl="API testing with CURL failed"
  kill $(cat $cb_test/BrainPortal/tmp/pids/server.pid)
fi



# ------------------------------
# Testing of API (Ruby Gem)
# ------------------------------
printf "${BLUE}Running API tests with Ruby CbrainClient gem.${NC}\n"
if echo "X$CBRAIN_SKIP_TEST_STAGES" | grep -q 'GemAPI' >/dev/null ; then
  printf "${YELLOW} -> Skipped by request from env CBRAIN_SKIP_TEST_STAGES${NC}\n"
else
  cd $cb_test/BrainPortal            || die "Cannot cd to BrainPortal directory"
  rake "db:seed:test:api" >/dev/null || die "Cannot re-seed the DB for API testing"
  rails server puma -p 3000 -d       || die "Cannot start local puma server?"
  cd test_api                        || die "Cannot cd to test_api directory?"
  sleep 5 # must wait a bit for puma to be ready
  rake "cbrain:test:api:client"           \
    -v "${CBRAIN_GEM_TEST_VERBOSE_LEVEL}" \
    ${CBRAIN_GEM_TEST_FILTER}             \
    || fail_api_ruby="API testing with Ruby CbrainClient failed"
  kill $(cat $cb_test/BrainPortal/tmp/pids/server.pid)
fi



# ------------------------------
# Return status of both rspec
# ------------------------------
test -z "$fail_portal$fail_bourreau$fail_api_curl$fail_api_ruby" && exit 0  # Pangloss
echo ""
printf "${YELLOW}**** Summary of command failures ****${NC}\n"
test -n "$fail_portal"   && printf "${RED}$fail_portal${NC}\n"
test -n "$fail_bourreau" && printf "${RED}$fail_bourreau${NC}\n"
test -n "$fail_api_curl" && printf "${RED}$fail_api_curl${NC}\n"
test -n "$fail_api_ruby" && printf "${RED}$fail_api_ruby${NC}\n"
printf "${YELLOW}**** --------------------------- ****${NC}\n"
echo ""
exit 2


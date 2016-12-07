#!/bin/bash

# This script is run as root as the entry point of
# the CBRAIN docker container for running tests;
# it basically just starts the DB server then
# invokes cb_run_tests.sh as user 'cbrain'.

set -e # exit as soon as any command fails

if test "$UID" -ne 0 ; then
  echo "This script is meant to be run as the entry point"
  echo "to the docker container for running tests."
  exit 2
fi

MAGENTA='\033[35m'
NC='\033[0m'

printf "${MAGENTA}Container bootstrap script starting at %s ${NC}\n" "$(date '+%F %T')"

test_user="cbrain"            # normal user to run test suite
test_script="cb_run_tests.sh" # the script for running the suite

echo "Starting DB server as root"
service mysqld start || exit 2
echo "Running test script '$test_script' as user '$test_user'"
su -c "bash --login -c /home/cbrain/cbrain_travis/Travis/$test_script" $test_user


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
mysqld_safe &
started=""
for n in 1 2 3 4 5 ; do
  echo "Waiting for DB server ($n/5)"
  sleep 3
  started=$(ps ax -o cmd | grep -v mysqld_safe | grep mysql | grep -v grep | head -1 | cut -d" " -f1 )
  test -n "$started" && break
done
if test -z "$started" ; then
  echo "Error: cannot start DB server?!?"
  exit 2
else
  echo "DB server started."
  echo ""
fi

echo "Running test script '$test_script' as user '$test_user'"
su -c "bash --login -c /home/cbrain/cbrain_travis/Travis/$test_script" $test_user


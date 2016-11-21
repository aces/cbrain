#!/bin/bash

###############################################################################
#                                                                             #
# This script is used by Travis CI (https://travis-ci.org/) to run the        #
# CBRAIN test suite.                                                          #
#                                                                             #
# The script expects a testing docker container to already have been built    #
# and made available from the local system. The name of that docker image is  #
# expected in the environement variable $CBRAIN_CI_IMAGE_NAME, or given as a  #
# first argument to the script.                                               #
#                                                                             #
# This script does the following:                                             #
#   - Invoke the container as part of a docker-compose setup, which           #
#     links the image to a MariaDB service.                                   #
#   - Run the testing suite inside the container.                             #
#   - Returns the return code (and possibly diagnostics) of the suite.        #
#                                                                             #
###############################################################################

# Terminal colors, using ANSI sequences.
RED='\033[31m'
GREEN='\033[32m'
MAGENTA='\033[35m'
NC='\033[0m'

# Do we even have a Travis+Docker environment set up ?
if test ! -d Travis ; then
  printf "${RED}No 'Travis' subdirectory found.${NC}\n"
  echo "Please invoke this program from the root of the CBRAIN project."
  exit 2 # config error
fi
cd Travis || exit 2

# Do we have a docker image name to run?
CBRAIN_CI_IMAGE_NAME=${CBRAIN_CI_IMAGE_NAME:-$1} # can be given as argument
if test "X$CBRAIN_CI_IMAGE_NAME" = "X" ; then
  printf "${RED}No CBRAIN_CI_IMAGE_NAME environment variable supplied.${NC}\n"
  exit 2 # config error
fi

# Count time
SECONDS=0 # bash is great

# Run the docker containers
printf "${MAGENTA}Running containers in Docker Compose.${NC}\n"
compose_project_name='travis' # used to refer to docker services: travis_cbrain_1, travis_mysql_1
cbrain_service="${compose_project_name}_cbrain_1" # docker compose convention
env CBRAIN_CI_IMAGE_NAME=$CBRAIN_CI_IMAGE_NAME docker-compose -p $compose_project_name up -d --force-recreate
if [ $? -ne 0 ] ; then
  printf "${RED}Docker Compose Failed. So sorry.${NC}\n"
  exit 10 # partial abomination
fi

# Print logs (always, by request).
# Also Travis CI will abort the test if nothing is printed for too long.
echo ""
printf "${MAGENTA}==== Docker logs start here ====${NC}\n"
docker logs ${cbrain_service} --follow
printf "${MAGENTA}==== Docker logs end here ====${NC}\n"
echo ""
test_exit_code=$(docker wait ${cbrain_service})
printf "${MAGENTA}Docker Compose finished after $SECONDS seconds.${NC}\n"
echo ""

# Final Results
if [ "X$test_exit_code" != "X0" ] ; then
  printf "${RED}===================================================${NC}\n"
  printf "${RED}Tests Failed${NC} - 'docker wait' exit code: $test_exit_code\n"
  printf "${RED}===================================================${NC}\n"
  exit 20 # total abomination
fi

# Yippee.
printf "${GREEN}===================================================${NC}\n"
printf "${GREEN}All tests Passed${NC}\n"
printf "${GREEN}===================================================${NC}\n"

# Important, eh, oh, not kidding here.
exit 0


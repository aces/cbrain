#!/bin/sh

###############################################################################
#                                                                             #
# This script is used by travis (https://travis-ci.org/) to build and test    #
# CBRAIN when a Pull Request is done.                                         #
#                                                                             #
# This script do the following:                                               #
#   - Create some docker containers to run the testing suite.                 #
#   - Run the testing suit inside the cbrain_portal container.                #
#   - If all the test pass then travis will pass otherwise it will fail.      #
#                                                                             #
###############################################################################


# Terminal colors, using ANSI sequences.
RED='\033[31m'
GREEN='\033[32m'
MAGENTA='\033[35m'
NC='\033[0m'

# Do we even have a Docker environment set up ?
cd Travis
if [ $? -ne 0 ] ; then
  printf "${RED}No 'Travis' subdirectory found.${NC}\n"
  exit 2
fi

# Construction of docker containers
printf "${MAGENTA} Building docker containers.${NC}\n"
bash build.sh
if [ $? -ne 0 ] ; then
  printf "${RED}Construction of docker containers failed.${NC}\n"
  exit 5
fi

COMPOSE_PROJECT_NAME='travis'

# Run the docker containers
printf "${MAGENTA} Running docker containers.${NC}\n"
env USERID=500 GROUPID=500 docker-compose -p 'travis' up -d
if [ $? -ne 0 ] ; then
  printf "${RED}Docker Compose Failed${NC}\n"
  exit 10
fi
TEST_EXIT_CODE=`docker wait travis_cbrain-portal_1`

# Final Results
if [ -z "${TEST_EXIT_CODE}" ] || [ "$TEST_EXIT_CODE" -ne 0 ] ; then
  printf "${RED}Tests Failed${NC} - 'docker wait' exit code: $TEST_EXIT_CODE\n"
  docker logs travis_cbrain-portal_1
  exit 20
fi

printf "${GREEN}Tests Passed${NC}\n"
exit 0

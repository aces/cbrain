#!/bin/sh

###############################################################################
#                                                                             #
# This script is used by Travis CI (https://travis-ci.org/) to run the        #
# CBRAIN test suite.                                                          #
#                                                                             #
# The script expects a testing docker container to already have been built    #
# and made available from the local system. The name of that docker image is  #
# expected in the environement variable $IMAGE_NAME, or given as a first      #
# argument.                                                                   #
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
  exit 2
fi
cd Travis

# Do we have a docker image name to run?
IMAGE_NAME=${IMAGE_NAME:-$1} # can be given as argument
if test "X$IMAGE_NAME" = "X" ; then
  printf "${RED}No IMAGE_NAME environment variable supplied.${NC}\n"
  exit 2
fi

# Count time
SECONDS=0 # bash is great

# Run the docker containers
printf "${MAGENTA}Running containers in Docker Compose.${NC}\n"
export COMPOSE_PROJECT_NAME='travis'
env IMAGE_NAME=$IMAGE_NAME docker-compose -p $COMPOSE_PROJECT_NAME up -d
if [ $? -ne 0 ] ; then
  printf "${RED}Docker Compose Failed. So sorry.${NC}\n"
  exit 10
fi
test_exit_code=`docker wait travis_cbrain_1`
printf "${MAGENTA}Docker Compose finished after $SECONDS seconds.${NC}\n"

# Final Results
if [ "X$test_exit_code" != "X0" ] ; then
  printf "${RED}Tests Failed${NC} - 'docker wait' exit code: $test_exit_code\n"
  docker logs travis_cbrain_1
  exit 20
fi

printf "${GREEN}All tests Passed${NC}\n"
exit 0


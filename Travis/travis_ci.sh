#!/bin/bash

###############################################################################
#                                                                             #
# This script is used by Travis CI (https://travis-ci.org/) to run the        #
# CBRAIN test suite.                                                          #
#                                                                             #
# The script expects a testing docker container to already have been built    #
# and made available from the local system. The name of that docker image is  #
# expected in the environment variable $CBRAIN_CI_IMAGE_NAME, or given as a   #
# first argument to the script.                                               #
#                                                                             #
# This script does the following:                                             #
#   - Invoke the container which runs the test suite                          #
#   - Wait for the container to finish, dumping its logs on the way           #
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
cbrain_travis="`pwd -P`" # Root of where the code to test is located.
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
printf "${MAGENTA}Launching CBRAIN test container at %s ${NC}\n" "$(date '+%F %T')"

# Note: to skip stages, set CBRAIN_SKIP_TEST_STAGES to
# one or several of the keywords 'RspecPortal', 'RspecBourreau',
# 'CurlAPI' or 'GemAPI', joined by commas or periods.
docker_name="cb_travis" # pretty name of the process
docker run -d \
           --env CBRAIN_SKIP_TEST_STAGES        \
           --env CBRAIN_CURL_TEST_VERBOSE_LEVEL \
           --env CBRAIN_CURL_TEST_FILTER        \
           --env CBRAIN_GEM_TEST_VERBOSE_LEVEL  \
           --env CBRAIN_GEM_TEST_FILTER         \
           -v "$cbrain_travis":/home/cbrain/cbrain_travis \
           --name "$docker_name" \
           ${CBRAIN_CI_IMAGE_NAME} | perl -ne 'print unless /^[0-9a-f]{64}\n$/'
if [ $? -ne 0 ] ; then
  printf "${RED}Docker Start Failed. So sorry.${NC}\n"
  exit 10 # partial abomination
fi

# Print logs (always, by request).
# Also Travis CI will abort the test if nothing is printed for too long.
echo ""
printf "${MAGENTA}==== Docker logs start here ====${NC}\n"
docker logs ${docker_name} --follow
printf "${MAGENTA}==== Docker logs end here ====${NC}\n"
echo ""
test_exit_code=$(docker wait ${docker_name})
docker rm ${docker_name} >/dev/null || true
printf "${MAGENTA}Docker container finished after $SECONDS seconds.${NC}\n"
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


#!/bin/bash -e

CBRAIN_REPO="https://github.com/aces/cbrain.git"
CBRAIN_BRANCH="dev"
IMAGE_NAME="mcin/cbrain_travis"

function usage {
  cat <<USAGE
Usage: $0 [-h] -b [image_name] [cbrain_repo] [cbrain_branch]

This script builds a Docker image suitable
for testing the CBRAIN framework. It can then
be used to run continuous integration testing
within Travis CI.

Options
  -h : prints this helps.
  -b : required to trigger the build

Arguments

  image_name : the name of the docker image.
  Default: "$IMAGE_NAME"

  cbrain_repo : the GIT repo for CBRAIN that
  will be used to build the 'base' installation.
  This is meant to speed up testing as the
  image we are building here will already have
  Ruby, rvm, and the gems of that repo pre-installed.
  Default: "$CBRAIN_REPO"

  cbrain_branch : a branch of the repo above, for
  the pre-install.
  Default: "$CBRAIN_BRANCH"

Providing empty strings ("") for any of these arguments
allows you to use the default values shown above.

USAGE
  exit 2
}

# Validate options and arguments
test "$#" -eq 0    && usage  # no args?
test "X$1" = "X-h" && usage  # starts with -h ?
test "X$1" = "X-b" || usage ; shift # must start with -b
test "$#" -gt 3    && usage  # too many args
test "$#" -gt 0    && IMAGE_NAME="${1:-$IMAGE_NAME}"       && shift
test "$#" -gt 0    && CBRAIN_REPO="${1:-$CBRAIN_REPO}"     && shift
test "$#" -gt 0    && CBRAIN_BRANCH="${1:-$CBRAIN_BRANCH}" && shift

# Check we're running in the proper dir.
if test ! -f "Dockerfile.travis" ; then
  echo "Cannot find Dockerfile.travis in the current directory."
  exit 2
fi

echo
echo "#################################"
echo "# Building CBRAIN testing base  #"
echo "#################################"
echo

# Build the container
docker build \
  -f Dockerfile.travis \
  --build-arg "CBRAIN_REPO=$CBRAIN_REPO" \
  --build-arg "CBRAIN_BRANCH=$CBRAIN_BRANCH" \
  -t "$IMAGE_NAME" .

# Not ok?
if test $? -ne 0 ; then
  echo "Build failed. Sorry."
  exit 2
fi

# Tag it
docker tag "$IMAGE_NAME" "$IMAGE_NAME:$CBRAIN_BRANCH"

cat <<FINAL

Docker image complete: Name=$IMAGE_NAME:$CBRAIN_BRANCH
Push it to a repo or registry to use it for testing.

FINAL

exit 0

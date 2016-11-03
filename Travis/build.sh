#!/bin/bash -e

function usage {
  echo "usage: $0 [-h] [version]"
  echo "       -h: prints help."
  exit 2
}

while [ "$#" -gt 0 ] ; do
  case $1 in
    "-h") usage;;
    *) break;;
  esac
  shift
done

if test "$#" -gt 1 ; then
  usage
fi


PARENT_DIR=$(pwd -P)
ROOT_DIR=$(dirname ${PARENT_DIR})
cd $ROOT_DIR


DOCKERFILES_DIR=Travis/Dockerfiles
IMAGE_NAME=mcin/cbrain

echo
echo "#########################"
echo "# Building CBRAIN base  #"
echo "#########################"
echo

docker build -f ${DOCKERFILES_DIR}/Dockerfile -t ${IMAGE_NAME} .
docker tag ${IMAGE_NAME} ${IMAGE_NAME}:travis

echo
echo "#########################"
echo "#    Building Portal    #"
echo "#########################"
echo

docker build -f ${DOCKERFILES_DIR}/Dockerfile.Portal -t ${IMAGE_NAME}_portal .
docker tag ${IMAGE_NAME}_portal ${IMAGE_NAME}_portal:travis

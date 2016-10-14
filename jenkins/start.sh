#!/bin/bash

if [[ $# < 3 ]] ; then
    echo "You have to pass three params"
    echo "1 - git username with access to the forked repos"
    echo "2 - git password of that user"
    echo "3 - org where the forked repos lay"
    echo "Example: ./start.sh user pass forkedRepo"
    exit 0
fi

PIPELINE_GIT_USERNAME="${1}"
PIPELINE_GIT_PASSWORD="${2}"
export FORKED_ORG="${3}"

mkdir -p build
rm -rf build/gituser
rm -rf build/gitpass
echo "${PIPELINE_GIT_USERNAME}" >> build/gituser
echo "${PIPELINE_GIT_PASSWORD}" >> build/gitpass

docker-compose build
docker-compose up -d
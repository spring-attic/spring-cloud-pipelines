#!/bin/bash

if [[ $# < 3 ]] ; then
    echo "You have to pass three params"
    echo "1 - git username with access to the forked repos"
    echo "2 - git password of that user"
    echo "3 - org where the forked repos lay"
    echo "Example: ./start.sh user pass forkedRepo"
    exit 0
fi

export PIPELINE_GIT_USERNAME="${1}"
export PIPELINE_GIT_PASSWORD="${2}"
export FORKED_ORG="${3}"

docker-compose build
docker-compose up -d
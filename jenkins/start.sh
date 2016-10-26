#!/bin/bash

if [[ $# < 3 ]] ; then
    echo "You have to pass three params"
    echo "1 - git username with access to the forked repos"
    echo "2 - git password of that user"
    echo "3 - org where the forked repos lay"
    echo "4 - (optional) external ip (for example Docker Machine if you're using one)"
    echo "Example: ./start.sh user pass forkedOrg 192.168.99.100"
    exit 0
fi

export PIPELINE_GIT_USERNAME="${1}"
export PIPELINE_GIT_PASSWORD="${2}"
export FORKED_ORG="${3}"
export EXTERNAL_IP="${4}"

if [[ -z "${EXTERNAL_IP}" ]]; then
    EXTERNAL_IP=`echo ${DOCKER_HOST} | cut -d ":" -f 2 | cut -d "/" -f 3`
    if [[ -z "${EXTERNAL_IP}" ]]; then
        EXTERNAL_IP="$( ./whats_my_ip.sh )"
    fi
fi

echo "Forked organization [${FORKED_ORG}]"
echo "External IP [${EXTERNAL_IP}]"

docker-compose build
docker-compose up -d
#!/bin/bash

if [[ $# < 3 ]] ; then
    echo "You have to pass three params"
    echo "1 - git username with access to the forked repos or \"-key\" if using private key authentication instead"
    echo "2 - git password of that user or path to the private SSH key file if \"-key\" option is specified"
    echo "3 - org or your user id where the forked repos lay"
    echo "4 - (for k8s) docker registry organization - you can leave an empty value"
    echo "5 - (for k8s) docker registry username - you can leave an empty value"
    echo "6 - (for k8s) docker registry password - you can leave an empty value"
    echo "7 - (for k8s) docker registry email - you can leave an empty value"
    echo "8 - (optional) external ip (for example Docker Machine if you're using one)"
    echo "Example: ./start.sh user pass forkedOrg dockerOrg dockerUser dockerPass dockerEmail"
    echo "Example: ./start.sh -key ~/.ssh/my_key forkedOrg dockerOrg dockerUser dockerPass dockerEmail"
    echo "Example: ./start.sh user pass forkedOrg dockerOrg dockerUser dockerPass dockerEmail 192.168.99.100"
    echo "Example: ./start.sh user pass forkedOrg '' '' '' '' 192.168.99.100"
    exit 0
fi

GIT_AUTH_MODE="username/password"

export PIPELINE_GIT_USERNAME="${1}"
export PIPELINE_GIT_PASSWORD="${2}"
export FORKED_ORG="${3}"
export DOCKER_REGISTRY_ORGANIZATION="${4}"
export DOCKER_REGISTRY_USERNAME="${5}"
export DOCKER_REGISTRY_PASSWORD="${6}"
export DOCKER_REGISTRY_EMAIL="${7}"
export EXTERNAL_IP="${8}"

if [ "-key" == ${PIPELINE_GIT_USERNAME} ]; then
	export PIPELINE_GIT_USERNAME=""
	export PIPELINE_GIT_SSH_KEY="$(cat ${PIPELINE_GIT_PASSWORD})"
	export PIPELINE_GIT_PASSWORD=""
	GIT_AUTH_MODE="private key"
fi

if [[ -z "${EXTERNAL_IP}" ]]; then
    EXTERNAL_IP=`echo ${DOCKER_HOST} | cut -d ":" -f 2 | cut -d "/" -f 3`
    if [[ -z "${EXTERNAL_IP}" ]]; then
        EXTERNAL_IP="$( ./whats_my_ip.sh )"
    fi
fi

echo "Git authentication mode [${GIT_AUTH_MODE}]"
echo "Forked organization [${FORKED_ORG}]"
echo "External IP [${EXTERNAL_IP}]"

# Kubernetes
echo "Copying Kubernetes certificates"
cp ~/.minikube/ca.crt seed/k8s/ || echo "Failed to copy Kubernetes certificate authority file"
cp ~/.minikube/apiserver.crt seed/k8s/ || echo "Failed to copy Kubernetes client certificate file"
cp ~/.minikube/apiserver.key seed/k8s/ || echo "Failed to copy Kubernetes client key file"

docker-compose build --no-cache
#docker-compose build
docker-compose up -d

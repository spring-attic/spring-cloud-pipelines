#!/bin/bash

ROOT_ADDRESS=${1:-localhost:8080}
ALIAS=${2:-docker}
USERNAME=${3:-username}
PASSWORD=${4:-changeme}

fly -t "${ALIAS}" login -c http://"${ROOT_ADDRESS}" -u="${USERNAME}" -p="${PASSWORD}"

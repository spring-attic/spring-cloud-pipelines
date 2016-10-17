#!/bin/bash
ROOT_ADDRESS=${1:-localhost}

echo "Provided external address is [${ROOT_ADDRESS}]"

export CONCOURSE_EXTERNAL_URL=http://${ROOT_ADDRESS}:8080
docker-compose up -d

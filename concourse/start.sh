#!/bin/bash
ROOT_ADDRESS=${1:-localhost}

export CONCOURSE_EXTERNAL_URL=http://${ROOT_ADDRESS}:8080
docker-compose up -d

#!/bin/bash

PIPELINE_NAME=${1:-github-webhook}
ALIAS=${2:-docker}
CREDENTIALS=${3:-credentials.yml}

fly -t "${ALIAS}" sp -p "${PIPELINE_NAME}" -c pipeline.yml -l "${CREDENTIALS}" -n

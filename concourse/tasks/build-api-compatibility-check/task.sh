#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export REPO_RESOURCE=repo
export TOOLS_RESOURCE=tools
export KEYVAL_RESOURCE=keyval
export KEYVALOUTPUT_RESOURCE=keyvalout
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "KeyVal resource folder is [${KEYVAL_RESOURCE}]"

# If you're using some other image with Docker change these lines
# shellcheck source=/dev/null
source /docker-lib.sh || echo "Failed to source docker-lib.sh... Hopefully you know what you're doing"
start_docker || echo "Failed to start docker... Hopefully you know what you're doing"

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh"

echo "${MESSAGE}"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit

# Find latest prod tag
latestProdTag=$("${GIT_BIN}" for-each-ref --sort=taggerdate --format '%(refname)' refs/tags/prod | tail -1)
export LATEST_PROD_TAG
LATEST_PROD_TAG="${latestProdTag#refs/tags/}"
echo "Latest prod tag is [${LATEST_PROD_TAG}]"

export PASSED_LATEST_PROD_TAG
PASSED_LATEST_PROD_TAG="${LATEST_PROD_TAG}"

# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/${SCRIPT_TO_RUN}"

passKeyValProperties

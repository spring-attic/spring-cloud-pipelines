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
[ -f /docker-lib.sh ] && source /docker-lib.sh || echo "Failed to source docker-lib.sh... Hopefully you know what you're doing"
if [ -n "$(type -t timeout)" ] && [ "$(type -t timeout)" = function ]; then timeout 10s start_docker || echo "Failed to start docker... Hopefully you know what you're doing"; fi
if [ -n "$(type -t gtimeout)" ] && [ "$(type -t gtimeout)" = function ]; then gtimeout 10s start_docker || echo "Failed to start docker... Hopefully you know what you're doing"; fi

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh"

echo "Building and uploading the projects artifacts"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit

# Find latest prod tag
latestProdTag="$(latestProdTagFromGit)"
export LATEST_PROD_TAG
LATEST_PROD_TAG="$(trimRefsTag "${latestProdTag}")"
echo "Latest prod tag is [${LATEST_PROD_TAG}]"
export PASSED_LATEST_PROD_TAG
PASSED_LATEST_PROD_TAG="${LATEST_PROD_TAG}"

echo "First running api compatibility check, so that what we commit and upload at the end is just built project"
# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/build_api_compatibility_check.sh"

echo "Running the build and upload script"
# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/build_and_upload.sh"

DEV_TAG="dev/${PROJECT_NAME}/${PASSED_PIPELINE_VERSION}"
TAG_FILE="${ROOT_FOLDER}/${REPO_RESOURCE}/tag"
echo "Tagging the project with dev tag [${DEV_TAG}]"
echo "${DEV_TAG}" > "${TAG_FILE}"
cp -r "${ROOT_FOLDER}/${REPO_RESOURCE}"/. "${ROOT_FOLDER}/${OUTPUT_RESOURCE}/"

passKeyValProperties

#!/bin/bash

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export REPO_RESOURCE=repo
export REPO_TAGS_RESOURCE=repo-with-tags
export TOOLS_RESOURCE=tools
export VERSION_RESOURCE=version
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Repo with tags resource folder is [${REPO_TAGS_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "Version resource folder is [${VERSION_RESOURCE}]"

# If you're using some other image with Docker change these lines
# shellcheck source=/dev/null
source /docker-lib.sh || echo "Failed to source docker-lib.sh... Hopefully you know what you're doing"
start_docker || echo "Failed to start docker... Hopefully you know what you're doing"

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh"

pushd "${ROOT_FOLDER}/${REPO_TAGS_RESOURCE}" || exit
# shellcheck source=/dev/null
source "${SCRIPTS_OUTPUT_FOLDER}/pipeline.sh"
findLatestProdTag
echo "Latest prod tag is "${LATEST_PROD_TAG}""
popd

echo "${MESSAGE}"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit

# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/${SCRIPT_TO_RUN}"

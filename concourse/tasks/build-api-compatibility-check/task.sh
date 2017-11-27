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

echo "Preparing the private key"
mkdir -p ~/.ssh
echo "${GITHUB_PRIVATE_KEY}" > ~/.ssh/id_rsa
host="$( echo ${APP_URL/#git\@/} | cut -d: -f1 )"
echo "Extracted [${host}] from the [${APP_URL}]"
ssh-keyscan "${host}" >> ~/.ssh/known_hosts

echo "${MESSAGE}"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit
git fetch
findLatestProdTag
echo "Latest prod tag is "${LATEST_PROD_TAG}""

# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/${SCRIPT_TO_RUN}"

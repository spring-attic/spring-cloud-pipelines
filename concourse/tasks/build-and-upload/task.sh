#!/bin/bash

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export REPO_RESOURCE=repo
export TOOLS_RESOURCE=tools
export VERSION_RESOURCE=version
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "Version resource folder is [${VERSION_RESOURCE}]"

# If you're using some other image with Docker change these lines
# shellcheck source=/dev/null
source /docker-lib.sh || echo "Failed to source docker-lib.sh... Hopefully you know what you're doing"
start_docker || echo "Failed to start docker... Hopefully you know what you're doing"

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh"

echo "Building and uploading the projects artifacts"
cd "${ROOT_FOLDER}"/"${REPO_RESOURCE}" || exit

# shellcheck source=/dev/null
. "${SCRIPTS_OUTPUT_FOLDER}/build_and_upload.sh"

echo "Tagging the project with dev tag"
echo "dev/${PIPELINE_VERSION}" > "${ROOT_FOLDER}/${REPO_RESOURCE}/tag"
cp -r "${ROOT_FOLDER}/${REPO_RESOURCE}"/. "${ROOT_FOLDER}/${OUTPUT_RESOURCE}/"

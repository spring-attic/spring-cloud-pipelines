#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export SCRIPTS_OUTPUT_FOLDER="${ROOT_FOLDER}/${REPO_RESOURCE}/ciscripts"
echo "Scripts will be copied to [${SCRIPTS_OUTPUT_FOLDER}]"

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/keyval-resource-util.sh"
exportKeyValProperties

echo "Copying pipelines scripts"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit
mkdir -p "${SCRIPTS_OUTPUT_FOLDER}" || echo "Failed to create the scripts output folder"
[[ -d "${ROOT_FOLDER}/${TOOLS_RESOURCE}/common/src/main/bash/" ]] && \
    cp -r "${ROOT_FOLDER}/${TOOLS_RESOURCE}"/common/src/main/bash/* "${SCRIPTS_OUTPUT_FOLDER}"/ || \
    echo "Failed to copy the scripts"
[[ -d "${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}/common/src/main/bash/" ]] && \
    cp -r "${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}"/common/src/main/bash/* "${SCRIPTS_OUTPUT_FOLDER}"/ || \
    echo "No custom scripts found"

echo "Retrieving version"
cp "${ROOT_FOLDER}/${VERSION_RESOURCE}/version" "${SCRIPTS_OUTPUT_FOLDER}"/
export PIPELINE_VERSION
PIPELINE_VERSION="$( cat "${SCRIPTS_OUTPUT_FOLDER}/${VERSION_RESOURCE}" )"
echo "Retrieved version is [${PIPELINE_VERSION}]"

export CI="CONCOURSE"

cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit

echo "Sourcing file with pipeline functions"
# shellcheck source=/dev/null
source "${SCRIPTS_OUTPUT_FOLDER}/pipeline.sh"

echo "Generating settings.xml / gradle properties for Maven in local m2"
# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}"/concourse/tasks/generate-settings.sh

# TODO Could move this function into common/src/main/bash/pipeline.sh and remove this source call (talk to Marcin)
# Used to delete prod tag in prod_rollback job
echo "Sourcing file with git resource util functions"
# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}"/concourse/tasks/git-resource-util.sh

export TERM=dumb

cd "${ROOT_FOLDER}" || exit

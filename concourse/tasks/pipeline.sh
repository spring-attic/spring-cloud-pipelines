#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export SCRIPTS_OUTPUT_FOLDER="${ROOT_FOLDER}/${REPO_RESOURCE}/ciscripts"
echo "Scripts will be copied to [${SCRIPTS_OUTPUT_FOLDER}]"

echo "Copying pipelines scripts"
cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit
mkdir -p "${SCRIPTS_OUTPUT_FOLDER}" || echo "Failed to create the scripts output folder"
[[ -d "${ROOT_FOLDER}/${TOOLS_RESOURCE}/common/src/main/bash/" ]] && \
    cp -r "${ROOT_FOLDER}/${TOOLS_RESOURCE}"/common/src/main/bash/* "${SCRIPTS_OUTPUT_FOLDER}"/ || \
    echo "Failed to copy the scripts"
[[ -d "${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}/common/src/main/bash/" ]] && \
    cp -r "${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}"/common/src/main/bash/* "${SCRIPTS_OUTPUT_FOLDER}"/ || \
    echo "No custom scripts found"

echo "Sourcing file with resource util functions"
# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/resource-utils.sh"
exportKeyValProperties

export PIPELINE_VERSION
PIPELINE_VERSION="${PASSED_PIPELINE_VERSION}"
export LATEST_PROD_TAG
LATEST_PROD_TAG="${PASSED_LATEST_PROD_TAG}"

echo "Current version is [${PIPELINE_VERSION}]"

export CI="CONCOURSE"

cd "${ROOT_FOLDER}/${REPO_RESOURCE}" || exit

echo "Sourcing file with pipeline functions"
# shellcheck source=/dev/null
source "${SCRIPTS_OUTPUT_FOLDER}/pipeline.sh"

echo "Generating settings.xml / gradle properties for Maven in local m2"
# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}"/concourse/tasks/generate-settings.sh

export TERM=dumb

cd "${ROOT_FOLDER}" || exit

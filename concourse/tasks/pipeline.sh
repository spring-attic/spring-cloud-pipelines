#!/bin/bash

export SCRIPTS_OUTPUT_FOLDER=${ROOT_FOLDER}/${REPO_RESOURCE}/ciscripts
echo "Scripts will be copied to [${SCRIPTS_OUTPUT_FOLDER}]"

echo "Copying pipelines scripts"
cd ${ROOT_FOLDER}/${REPO_RESOURCE}
mkdir ${SCRIPTS_OUTPUT_FOLDER}
cp -r ${ROOT_FOLDER}/${TOOLS_RESOURCE}/common/src/main/bash/* ${SCRIPTS_OUTPUT_FOLDER}/
[[ -d "${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}" ]] && \
    cp -r ${ROOT_FOLDER}/${CUSTOM_SCRIPT_IDENTIFIER}/common/src/main/bash/* ${SCRIPTS_OUTPUT_FOLDER}/ || \
    echo "No custom scripts found"

echo "Retrieving version"
cp ${ROOT_FOLDER}/${VERSION_RESOURCE}/version ${SCRIPTS_OUTPUT_FOLDER}/
export PIPELINE_VERSION=$( cat ${SCRIPTS_OUTPUT_FOLDER}/${VERSION_RESOURCE} )
echo "Retrieved version is [${PIPELINE_VERSION}]"

export CI="CONCOURSE"

cd ${ROOT_FOLDER}/${REPO_RESOURCE}

echo "Sourcing file with pipeline functions"
source ${SCRIPTS_OUTPUT_FOLDER}/pipeline.sh

echo "Generating settings.xml / gradle properties for Maven in local m2"
source ${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/generate-settings.sh

export TERM=dumb

cd ${ROOT_FOLDER}

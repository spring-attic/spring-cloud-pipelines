#!/bin/bash

export SCRIPTS_OUTPUT_FOLDER=${ROOT_FOLDER}/${REPO_RESOURCE}/ciscripts
echo "Scripts will be copied to [${SCRIPTS_OUTPUT_FOLDER}]"

echo "Copying pipelines scripts"
cd ${ROOT_FOLDER}/${REPO_RESOURCE}
mkdir ${SCRIPTS_OUTPUT_FOLDER}
cp ${ROOT_FOLDER}/${TOOLS_RESOURCE}/common/src/main/bash/* ${SCRIPTS_OUTPUT_FOLDER}/

echo "Retrieving version"
cp ${ROOT_FOLDER}/${VERSION_RESOURCE}/version ${SCRIPTS_OUTPUT_FOLDER}/
export PIPELINE_VERSION=$( cat ${SCRIPTS_OUTPUT_FOLDER}/${VERSION_RESOURCE} )
echo "Retrieved version is [${PIPELINE_VERSION}]"

M2_LOCAL=${ROOT_FOLDER}/${M2_REPO}
echo "Changing the maven local to [${M2_LOCAL}]"
export MAVEN_ARGS="-Dmaven.repo.local=${M2_LOCAL}"

export CI="CONCOURSE"

echo "Sourcing file with pipeline functions"
source ${SCRIPTS_OUTPUT_FOLDER}/pipeline.sh

export TERM=dumb

cd ${ROOT_FOLDER}
#!/bin/bash

export ROOT_FOLDER=$( pwd )
export REPO_RESOURCE=repo
export TOOLS_RESOURCE=tools
export VERSION_RESOURCE=version
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "Version resource folder is [${VERSION_RESOURCE}]"

source ${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh

echo "Generating settings.xml for Maven in local m2"
. ${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/generate-settings.sh

echo "Building and uploading the projects artifacts"
cd ${ROOT_FOLDER}/${REPO_RESOURCE}

. ${SCRIPTS_OUTPUT_FOLDER}/build_and_upload.sh

echo "Tagging the project with dev tag"
mkdir -p ${ROOT_FOLDER}/${REPO_RESOURCE}/${OUTPUT_FOLDER}/
echo "dev/${PIPELINE_VERSION}" > ${ROOT_FOLDER}/${REPO_RESOURCE}/${OUTPUT_FOLDER}/tag
cp -r ${ROOT_FOLDER}/${REPO_RESOURCE}/. ${ROOT_FOLDER}/${OUTPUT_RESOURCE}/

# WE CAN USE OUTPUT TO ARCHIVE THE RESULTS?
#mkdir -p ${OUTPUT_RESOURCE}/junit
#find . -type f -regex ".*/${OUTPUT_FOLDER}/.*-reports/.*" -exec cp {} ${OUTPUT_RESOURCE}/junit/ \;

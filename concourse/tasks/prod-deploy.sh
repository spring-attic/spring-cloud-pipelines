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

echo "Deploying the built application on prod environment"
cd ${ROOT_FOLDER}/${REPO_RESOURCE}

. ${SCRIPTS_OUTPUT_FOLDER}/prod_deploy.sh

echo "Tagging the project with prod tag"
mkdir -p ${ROOT_FOLDER}/${REPO_RESOURCE}/${OUTPUT_FOLDER}/
echo "prod/${PIPELINE_VERSION}" > ${ROOT_FOLDER}/${REPO_RESOURCE}/${OUTPUT_FOLDER}/tag
cp -r ${ROOT_FOLDER}/${REPO_RESOURCE}/. ${ROOT_FOLDER}/${OUTPUT_RESOURCE}/

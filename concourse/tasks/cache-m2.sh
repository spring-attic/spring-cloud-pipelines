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

M2_LOCAL=${ROOT_FOLDER}/${M2_REPO}
echo "Changing the maven local to [${M2_LOCAL}]"
export MAVEN_ARGS="-Dmaven.repo.local=${M2_LOCAL}"

if [ "$1" == "init" ]; then
	mkdir -p ${M2_LOCAL}
fi

cd ${REPO_RESOURCE}
./mvnw clean verify install ${MAVEN_ARGS}
cd ${ROOT_FOLDER}/m2
tar -C rootfs -cf rootfs.tar .
mv rootfs.tar ${ROOT_FOLDER}/to-push/

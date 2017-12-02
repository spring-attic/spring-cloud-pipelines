#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export REPO_RESOURCE=repo
export TOOLS_RESOURCE=tools
export KEYVAL_RESOURCE=keyval
export KEYVALOUTPUT_RESOURCE=keyvalout
export OUTPUT_RESOURCE=out

echo "Root folder is [${ROOT_FOLDER}]"
echo "Repo resource folder is [${REPO_RESOURCE}]"
echo "Tools resource folder is [${TOOLS_RESOURCE}]"
echo "KeyVal resource folder is [${KEYVAL_RESOURCE}]"

# shellcheck source=/dev/null
source "${ROOT_FOLDER}/${TOOLS_RESOURCE}/concourse/tasks/pipeline.sh"

M2_LOCAL="${ROOT_FOLDER}/${M2_REPO}/repository"
echo "Changing the maven local to [${M2_LOCAL}]"
export BUILD_OPTIONS="-Dmaven.repo.local=${M2_LOCAL}"

if [ "$1" == "init" ]; then
	mkdir -p "${M2_LOCAL}"
fi

cd "${REPO_RESOURCE}" || exit
./mvnw --fail-never dependency:go-offline "${BUILD_OPTIONS}" || (./gradlew clean install -PM2_LOCAL="${M2_LOCAL}" || echo "Sth went wrong" )
cd "${ROOT_FOLDER}/m2" || exit
tar -C rootfs -cf rootfs.tar .
mv rootfs.tar "${ROOT_FOLDER}/to-push/"

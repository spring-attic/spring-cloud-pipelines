#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export KEYVALOUTPUT_RESOURCE=keyvalout

propsDir="${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
propsFile="${propsDir}/keyval.properties"

mkdir -p "${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
touch "${propsFile}"

VERSION="1.0.0.M1-$(date +%Y%m%d_%H%M%S)-VERSION"
MESSAGE="[Concourse CI] Bump to Next Version ($VERSION)"

git clone version updated-version
pushd updated-version
  git config --local user.email "${GIT_EMAIL}"
  git config --local user.name "${GIT_NAME}"

  echo "Bump to ${VERSION}"
  echo "${VERSION}" > version

  git add version
  git commit -m "${MESSAGE}"
popd

echo "Adding: PASSED_PIPELINE_VERSION: [${VERSION}]"
echo "PASSED_PIPELINE_VERSION=${VERSION}" >> "${propsFile}"

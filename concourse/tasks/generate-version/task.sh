#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export ROOT_FOLDER
ROOT_FOLDER="$( pwd )"
export KEYVALOUTPUT_RESOURCE=keyvalout
export GIT_BIN="${GIT_BIN:-git}"

propsDir="${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
propsFile="${propsDir}/keyval.properties"

mkdir -p "${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
touch "${propsFile}"

VERSION="1.0.0.M1-$(date +%Y%m%d_%H%M%S)-VERSION"
MESSAGE="[Concourse CI] Bump to Next Version ($VERSION)"

"${GIT_BIN}" clone version updated-version
pushd updated-version
  "${GIT_BIN}" config --local user.email "${GIT_EMAIL}"
  "${GIT_BIN}" config --local user.name "${GIT_NAME}"

  echo "Bump to ${VERSION}"
  echo "${VERSION}" > version

  "${GIT_BIN}" add version
  "${GIT_BIN}" commit -m "${MESSAGE}"
popd

echo "Adding: PASSED_PIPELINE_VERSION: [${VERSION}]"
echo "PASSED_PIPELINE_VERSION=${VERSION}" >> "${propsFile}"

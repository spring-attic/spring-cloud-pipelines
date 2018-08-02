#!/bin/bash
set -o errexit
set -o errtrace
set -o pipefail

function fetchLatestProdJar() {
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)
	# Downloading latest jar
	echo "Last prod version equals ${LATEST_PROD_VERSION}"
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${LATEST_PROD_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
	mv "$(pwd)/${OUTPUT_FOLDER}/${appName}-${LATEST_PROD_VERSION}.${BINARY_EXTENSION}" "$(pwd)/${OUTPUT_FOLDER}/${appName}-${LATEST_PROD_VERSION}-latestprodversion.${BINARY_EXTENSION}"
}

export PAAS_TYPE=CF
export ENVIRONMENT=BUILD

# shellcheck source=/dev/null
source "${WORKSPACE}"/.git/tools/common/src/main/bash/pipeline.sh

# Find latest prod version
readTestPropertiesFromFile "${OUTPUT_FOLDER}/trigger.properties"
cat "${OUTPUT_FOLDER}/trigger.properties"
if [[ -z "${LATEST_PROD_VERSION}" ]]; then
	echo "No prod release took place - skipping this step"
else
	fetchLatestProdJar
fi

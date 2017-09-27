#!/bin/bash

set -e

# It takes ages on Docker to run the app without this
# Also we want to disable the progress indicator for downloaded jars
export MAVEN_OPTS="${MAVEN_OPTS} -Djava.security.egd=file:///dev/urandom -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
export BINARY_EXTENSION="${BINARY_EXTENSION:-jar}"

function downloadAppBinary() {
	local repoWithJars="${1}"
	local groupId="${2}"
	local artifactId="${3}"
	local version="${4}"
	local destination
	local changedGroupId
	local pathToJar

	destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
	changedGroupId="$(echo "${groupId}" | tr . /)"
	pathToJar="${repoWithJars}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.${BINARY_EXTENSION}"
	mkdir -p "${OUTPUT_FOLDER}"
	echo "Current folder is [$(pwd)]; Downloading [${pathToJar}] to [${destination}]"
	(curl "${pathToJar}" -o "${destination}" --fail && echo "File downloaded successfully!") || (echo "Failed to download file!" && return 1)

}

function isMavenProject() {
	[ -f "mvnw" ]
}

function isGradleProject() {
	[ -f "gradlew" ]
}

# TODO: consider also a project descriptor file
# that could override these values
function projectType() {
	if isMavenProject; then
		echo "MAVEN"
	elif isGradleProject; then
		echo "GRADLE"
	else
		echo "UNKNOWN"
	fi
}

PROJECT_TYPE=$(projectType)

export -f projectType
export PROJECT_TYPE

echo "Project type [${PROJECT_TYPE}]"

lowerCaseProjectType=$(echo "${PROJECT_TYPE}" | tr '[:upper:]' '[:lower:]')
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline-${lowerCaseProjectType}.sh" ]] &&  \
 source "${__DIR}/pipeline-${lowerCaseProjectType}.sh" ||  \
 echo "No ${__DIR}/pipeline-${lowerCaseProjectType}.sh found"

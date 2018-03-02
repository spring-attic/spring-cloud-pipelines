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
    local artifactRepo="${5}"
    local nexusApiBaseUrl="${6}"
    local repoId="${7}"
    if [[ "${artifactRepo}" == "nexus" ]]; then
        downloadAppBinaryFromNexus "${nexusApiBaseUrl}" "${repoId}" "${groupId}" "${artifactId}" "${version}"
    elif [[ "${artifactRepo}" == "nexus-3" ]]; then
        downloadAppBinaryFromNexus3 "${nexusApiBaseUrl}" "${repoId}" "${groupId}" "${artifactId}" "${version}"
    else
        downloadAppBinaryFromArtifactory "${repoWithJars}" "${groupId}" "${artifactId}" "${version}"
    fi
}

function downloadAppBinaryFromArtifactory() {
    local repoWithJars="${1}"
    local groupId="${2}"
    local artifactId="${3}"
    local version="${4}"
	local destination
	local changedGroupId
	local pathToJar
    destination="`pwd`/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
    changedGroupId="$( echo "${groupId}" | tr . / )"
    pathToJar="${repoWithJars}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.${BINARY_EXTENSION}"
    downloadArtifact "${destination}" "${pathToJar}"
}

function downloadAppBinaryFromNexus() {
    local nexusApiBaseUrl="${1}"
    local repoId="${2}"
    local groupId="${3}"
    local artifactId="${4}"
    local version="${5}"
    local destination
    local changedGroupId
    local pathToJar
    destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
    changedGroupId="$(echo "${groupId}" | tr . /)"
    pathToJar="${nexusApiBaseUrl}/service/local/artifact/maven/redirect?r=${repoId}&g=${changedGroupId}&a=${artifactId}&v=${version}"
    downloadArtifact "${destination}" "${pathToJar}"
}

function downloadAppBinaryFromNexus3() {
    local nexusApiBaseUrl="${1}"
    local repoId="${2}"
    local groupId="${3}"
    local artifactId="${4}"
    local version="${5}"
    local searchBaseUrl
    local nexusApiSearchUrl
    local nexusUsername
    local nexusPassword
    local destination
    local pathToJar
    searchBaseUrl="${nexusApiBaseUrl}/service/siesta/rest/beta/search"
    nexusApiSearchUrl="${searchBaseUrl}?repository=${repoId}&maven.groupId=${groupId}&maven.artifactId=${artifactId}&maven.baseVersion=${version}&maven.extension=${BINARY_EXTENSION}"
    nexusUsername=${M2_SETTINGS_SNAPSHOTS_REPO_USERNAME}
    nexusPassword=${M2_SETTINGS_SNAPSHOTS_REPO_PASSWORD}
    destination="`pwd`/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
    pathToJar=$(curl -u ${nexusUsername}:${nexusPassword} -X GET --header 'Accept: application/json' ${nexusApiSearchUrl} | jq --raw-output '.items | reverse[0].assets[0].downloadUrl')
    downloadArtifact "${destination}" "${pathToJar}"
}

function downloadArtifact() {
  local destination="${1}"
  local pathToJar="${2}"
  local username
  local password
  username=${M2_SETTINGS_SNAPSHOTS_REPO_USERNAME}
  password=${M2_SETTINGS_SNAPSHOTS_REPO_PASSWORD}
  if [[ ! -e ${destination} ]]; then
      mkdir -p "${OUTPUT_FOLDER}"
			echo "Current folder is [$(pwd)]; Downloading [${pathToJar}] to [${destination}]"
      (curl -u "${username}:${password}" "${pathToJar}" -o "${destination}" --fail && echo "File downloaded successfully!") || (echo "Failed to download file!" && return 1)
  else
      echo "File [${destination}] exists. Will not download it again"
  fi
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

# Setting a default when
[[ -z "${REPO_WITH_BINARIES_FOR_UPLOAD}" ]] && REPO_WITH_BINARIES_FOR_UPLOAD="${REPO_WITH_BINARIES}"

lowerCaseProjectType=$(echo "${PROJECT_TYPE}" | tr '[:upper:]' '[:lower:]')
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline-${lowerCaseProjectType}.sh" ]] &&  \
 source "${__DIR}/pipeline-${lowerCaseProjectType}.sh" ||  \
 echo "No ${__DIR}/pipeline-${lowerCaseProjectType}.sh found"

#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Script that knows how to define the concrete type of the JVM project.
# Scans for presence of files.
# }}}

# It takes ages on Docker to run the app without this
# Also we want to disable the progress indicator for downloaded jars
export MAVEN_OPTS="${MAVEN_OPTS} -Djava.security.egd=file:///dev/urandom -Dorg.slf4j.simpleLogger.log.org.apache.maven.cli.transfer.Slf4jMavenTransferListener=warn"
export BINARY_EXTENSION="${BINARY_EXTENSION:-jar}"

# FUNCTION: downloadAppBinary {{{
# Fetches a JAR from a binary storage
#
# $1 - URL to repo with binaries
# $2 - group id of the packaged sources
# $3 - artifact id of the packaged sources
# $4 - version of the packaged sources
function downloadAppBinary() {
	local repoWithJars="${1}"
	local groupId="${2}"
	local artifactId="${3}"
	local version="${4}"
	local artifactRepo="${5}"
	local nexusApiBaseUrl="${6}"
	local repoId="${7}"
	local username="${8}"
	local password="${9}"
	if [[ "${artifactRepo}" == "nexus" ]]; then
    	downloadAppBinaryFromNexus "${nexusApiBaseUrl}" "${repoId}" "${groupId}" "${artifactId}" "${version}" "${username}" "${password}"
	elif [[ "${artifactRepo}" == "nexus-3" ]]; then
    	downloadAppBinaryFromNexus3 "${nexusApiBaseUrl}" "${repoId}" "${groupId}" "${artifactId}" "${version}" "${username}" "${password}"
	else
    	downloadAppBinaryFromArtifactory "${repoWithJars}" "${groupId}" "${artifactId}" "${version}" "${username}" "${password}"
	fi
}

function downloadAppBinaryFromArtifactory() {
	local repoWithJars="${1}"
	local groupId="${2}"
	local artifactId="${3}"
	local version="${4}"
	local artifactoryUsername="${5}"
	local artifactoryPassword="${6}"
	local destination
	local changedGroupId
	local pathToJar
	destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
	changedGroupId="$( echo "${groupId}" | tr . / )"
	pathToJar="${repoWithJars}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.${BINARY_EXTENSION}"
	downloadArtifact "${destination}" "${pathToJar}" "${artifactoryUsername}" "${artifactoryPassword}"
}

function downloadAppBinaryFromNexus() {
	local nexusApiBaseUrl="${1}"
	local repoId="${2}"
	local groupId="${3}"
	local artifactId="${4}"
	local version="${5}"
	local nexusUsername="${6}"
	local nexusPassword="${7}"
	local destination
	local changedGroupId
	local pathToJar
	destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
	changedGroupId="$(echo "${groupId}" | tr . /)"
	pathToJar="${nexusApiBaseUrl}/service/local/artifact/maven/redirect?r=${repoId}&g=${changedGroupId}&a=${artifactId}&v=${version}"
	downloadArtifact "${destination}" "${pathToJar}" "${nexusUsername}" "${nexusPassword}"
}

function downloadAppBinaryFromNexus3() {
	local nexusApiBaseUrl="${1}"
	local repoId="${2}"
	local groupId="${3}"
	local artifactId="${4}"
	local version="${5}"
	local nexusUsername="${6:-$M2_SETTINGS_REPO_USERNAME}"
	local nexusPassword="${7:-$M2_SETTINGS_REPO_PASSWORD}"
	local searchBaseUrl
	local nexusApiSearchUrl
	local destination
	local pathToJar
	searchBaseUrl="${nexusApiBaseUrl}/service/siesta/rest/beta/search"
	nexusApiSearchUrl="${searchBaseUrl}?repository=${repoId}&maven.groupId=${groupId}&maven.artifactId=${artifactId}&maven.baseVersion=${version}&maven.extension=${BINARY_EXTENSION}"
	destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
	mkdir -p "${OUTPUT_FOLDER}"
	curl -u "${nexusUsername}:${nexusPassword}" -X GET --header "Accept: application/json" "${nexusApiSearchUrl}" -o "${OUTPUT_FOLDER}/artifacts.json" --fail && success="true"
	if [[ "${success}" == "true" ]]; then
		pathToJar="$(< "${OUTPUT_FOLDER}/artifacts.json" jq --raw-output '.items | reverse[0].assets[0].downloadUrl')"
		downloadArtifact "${destination}" "${pathToJar}" "${nexusUsername}" "${nexusPassword}"
	else
		echo "Failed to find path to jar!"
		return 1
	fi
}

function downloadArtifact() {
	local destination="${1}"
	local pathToJar="${2}"
	local username="${3:-$M2_SETTINGS_REPO_USERNAME}"
	local password="${4:-$M2_SETTINGS_REPO_PASSWORD}"
	mkdir -p "${OUTPUT_FOLDER}"
	echo "Current folder is [$(pwd)]; Downloading binary to [${destination}]"
	local success="false"
	curl -u "${username}:${password}" "${pathToJar}" -o "${destination}" --fail && success="true"
	if [[ "${success}" == "true" ]]; then
		echo "File downloaded successfully!"
		return 0
	else
		echo "Failed to download file!"
		return 1
	fi
} # }}}

# FUNCTION: isMavenProject {{{
# Returns true if Maven Wrapper is used
function isMavenProject() {
	[ -f "mvnw" ]
} # }}}

# FUNCTION: isGradleProject {{{
# Returns true if Gradle Wrapper is used
function isGradleProject() {
	[ -f "gradlew" ]
} # }}}

# FUNCTION: projectType {{{
# JVM implementation of projectType
function projectType() {
	if isMavenProject; then
		echo "MAVEN"
	elif isGradleProject; then
		echo "GRADLE"
	else
		echo "UNKNOWN"
	fi
} # }}}

[[ -z "${PROJECT_TYPE}" || "${PROJECT_TYPE}" == "null" ]] && PROJECT_TYPE=$(projectType)

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

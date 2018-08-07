#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Contains all PHP related build functions
# }}}

export DOTNET_BIN
DOTNET_BIN="${DOTNET_BIN:-dotnet}"
CURL_BIN="${CURL_BIN:-curl}"
BINARY_EXTENSION="${BINARY_EXTENSION:-zip}"
UNZIP_BIN="${UNZIP_BIN:-unzip}"

# ---- BUILD PHASE ----

# FUNCTION: build {{{
# Dotnet implementation of the build function.
function build() {
	export PROJECT_NAME PROJECT_GROUP PROJECT_VERSION
	PROJECT_NAME="$(retrieveAppName)"
	PROJECT_GROUP="$(retrieveGroupId)"
	PROJECT_VERSION="${PIPELINE_VERSION}"
	echo "Building"
	"${DOTNET_BIN}" build
	echo "Unit tests"
	"${DOTNET_BIN}" msbuild /nologo /t:CFPUnitTests
	echo "Integration tests"
	"${DOTNET_BIN}" msbuild /nologo /t:CFPIntegrationTests
	echo "Publishing"
	"${DOTNET_BIN}" msbuild /nologo /t:CFPPublish /p:Configuration=Release
} # }}}

# FUNCTION: downloadAppBinary {{{
# Fetches DotNet publication from a binary storage
#
# $1 - URL to repo with binaries
# $2 - group id of the packaged sources
# $3 - artifact id of the packaged sources
# $4 - version of the packaged sources
function downloadAppBinary() {
	local repoWithBinaries="${1}"
	local groupId="${2}"
	local artifactId="${3}"
	local version="${4}"
	local destination
	local changedGroupId
	local pathToArtifact
	destination="$(pwd)/${OUTPUT_FOLDER}/${artifactId}-${version}.${BINARY_EXTENSION}"
	changedGroupId="$(echo "${groupId}" | tr . /)"
	pathToArtifact="${repoWithBinaries}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.${BINARY_EXTENSION}"
	mkdir -p "${OUTPUT_FOLDER}"
	echo "Current folder is [$(pwd)]; Downloading binary from [${pathToArtifact}] to [${destination}]"
	local success="false"
	"${CURL_BIN}" -u "${M2_SETTINGS_REPO_USERNAME}:${M2_SETTINGS_REPO_PASSWORD}" "${pathToArtifact}" -o "${destination}" --fail && success="true"
	local outputDir
	outputDir="${OUTPUT_FOLDER}/${SOURCE_ARTIFACT_TYPE_NAME}"
	mkdir -p "${outputDir}"
	if [[ "${success}" == "true" ]]; then
		echo "File downloaded successfully!"
		"${UNZIP_BIN}" "${destination}" -d "${outputDir}"
		echo "File unpacked successfully"
		return 0
	else
		echo "Failed to download file!"
		return 1
	fi
} # }}}

# FUNCTION: executeApiCompatibilityCheck {{{
# Dotnet implementation of the execute API compatibility check
function executeApiCompatibilityCheck() {
	local latestProdVersion="${1}"
	export LATEST_PROD_VERSION
	LATEST_PROD_VERSION="${latestProdVersion}"
	export EXTERNAL_CONTRACTS_ARTIFACT_ID EXTERNAL_CONTRACTS_GROUP_ID EXTERNAL_CONTRACTS_PATH
	export EXTERNAL_CONTRACTS_CLASSIFIER EXTERNAL_CONTRACTS_VERSION
	EXTERNAL_CONTRACTS_ARTIFACT_ID="$(retrieveAppName)"
	EXTERNAL_CONTRACTS_GROUP_ID="$(retrieveGroupId)"
	EXTERNAL_CONTRACTS_PATH="/"
	EXTERNAL_CONTRACTS_CLASSIFIER="stubs"
	EXTERNAL_CONTRACTS_VERSION="${latestProdVersion}"
	"${DOTNET_BIN}" msbuild /nologo /t:CFPApiCompatibilityTest
} # }}}

# FUNCTION: retrieveGroupId {{{
# Dotnet implementation of the retrieve group id
function retrieveGroupId() {
	"${DOTNET_BIN}" msbuild /nologo /t:CFPGroupId | tail -1 | xargs
} # }}}

# FUNCTION: retrieveAppName {{{
# Dotnet implementation of the retrieve application name
function retrieveAppName() {
	if [[ "${PROJECT_NAME}" != "" && "${PROJECT_NAME}" != "${DEFAULT_PROJECT_NAME}" ]]; then
		echo "${PROJECT_NAME}"
	else
		"${DOTNET_BIN}" msbuild /nologo /t:CFPAppName | tail -1 | xargs
	fi
} # }}}

# FUNCTION: retrieveStubRunnerIds {{{
# Dotnet implementation of the retrieve stub runner ids
function retrieveStubRunnerIds() {
	"${DOTNET_BIN}" msbuild /nologo /t:CFPStubIds | tail -1 | xargs
} # }}}

# ---- TEST PHASE ----

# FUNCTION: runSmokeTests {{{
# Dotnet implementation of the run smoke tests
function runSmokeTests() {
	"${DOTNET_BIN}" msbuild /nologo /t:CFPSmokeTests
} # }}}

# ---- STAGE PHASE ----

# FUNCTION: runE2eTests {{{
# Dotnet implementation of the run e2e tests
function runE2eTests() {
	"${DOTNET_BIN}" msbuild /nologo /t:CFPE2eTests
} # }}}

# ---- COMMON ----

# FUNCTION: projectType {{{
# Dotnet implementation of the project type
function projectType() {
	echo "MSBUILD"
} # }}}

# FUNCTION: outputFolder {{{
# Dotnet implementation of the output folder
function outputFolder() {
	echo "target"
} # }}}

# FUNCTION: testResultsAntPattern {{{
# Dotnet implementation of the test results ant pattern
function testResultsAntPattern() {
	echo ""
} # }}}

# Setting a default when
[[ -z "${REPO_WITH_BINARIES_FOR_UPLOAD}" ]] && REPO_WITH_BINARIES_FOR_UPLOAD="${REPO_WITH_BINARIES}"

export ARTIFACT_TYPE
ARTIFACT_TYPE="${SOURCE_ARTIFACT_TYPE_NAME}"

echo "Checking dotnet version"
"${DOTNET_BIN}" --version
export DOWNLOADABLE_SOURCES
DOWNLOADABLE_SOURCES="true"

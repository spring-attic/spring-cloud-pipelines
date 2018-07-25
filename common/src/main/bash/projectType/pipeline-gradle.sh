#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Contains all Gradle related build functions
# }}}

export GRADLEW_BIN
GRADLEW_BIN="${GRADLEW_BIN:-./gradlew}"

# It takes ages on Docker to run the app without this
if [[ ${BUILD_OPTIONS} != *"java.security.egd"* ]]; then
	if [[ ! -z ${BUILD_OPTIONS} && ${BUILD_OPTIONS} != "null" ]]; then
		export BUILD_OPTIONS="${BUILD_OPTIONS} -Djava.security.egd=file:///dev/urandom"
	else
		export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	fi
fi

# FUNCTION: build {{{
# Gradle implementation of build. Sets version, passes build options and distribution management properties.
# Uses [PIPELINE_VERSION], [PASSED_PIPELINE_VERSION] and [M2_SETTINGS...], [REPO_WITH_BINARIES...] related env vars
function build() {
	local pipelineVersion="${PASSED_PIPELINE_VERSION:-${PIPELINE_VERSION:-}}"
	BUILD_OPTIONS="${BUILD_OPTIONS} -DM2_SETTINGS_REPO_USERNAME=${M2_SETTINGS_REPO_USERNAME} -DM2_SETTINGS_REPO_PASSWORD=${M2_SETTINGS_REPO_PASSWORD}"
	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" clean build deploy -PnewVersion="${pipelineVersion}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" -DREPO_WITH_BINARIES_FOR_UPLOAD="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" clean build deploy -PnewVersion="${pipelineVersion}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES}" -DREPO_WITH_BINARIES_FOR_UPLOAD="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS} || (echo "Build failed!!!" && return 1)
	fi
} # }}}

# FUNCTION: executeApiCompatibilityCheck {{{
# Gradle implementation of executing API compatibility check
function executeApiCompatibilityCheck() {
	local latestProdVersion="${1}"
	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" clean apiCompatibility -DlatestProductionVersion="${latestProdVersion}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" clean apiCompatibility -DlatestProductionVersion="${latestProdVersion}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: retrieveGroupId {{{
# Gradle implementation of group id retrieval
function retrieveGroupId() {
	"${GRADLEW_BIN}" groupId -q | tail -1
} # }}}

# FUNCTION: retrieveGroupId {{{
# Gradle implementation of app name retrieval
function retrieveAppName() {
	"${GRADLEW_BIN}" artifactId -q | tail -1
} # }}}

# FUNCTION: printTestResults {{{
# Prints test results. Used by Concourse.
function printTestResults() {
	# shellcheck disable=SC1117
	echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$(testResultsAntPattern)"
} # }}}

# FUNCTION: retrieveStubRunnerIds {{{
# Extracts the stub runner ids from the Gradle properties
function retrieveStubRunnerIds() {
	"${GRADLEW_BIN}" stubIds -q | tail -1
} # }}}

# FUNCTION: runSmokeTests {{{
# Given [APPLICATION_URL] and [STUBRUNNER_URL] will run the tests via [smoke] task
function runSmokeTests() {
	local pipelineVersion="${PASSED_PIPELINE_VERSION:-${PIPELINE_VERSION:-}}"
	local applicationUrl="${APPLICATION_URL}"
	local stubrunnerUrl="${STUBRUNNER_URL}"
	echo "Running smoke tests. Application url [${applicationUrl}], Stubrunner Url [${stubrunnerUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" smoke -PnewVersion="${pipelineVersion}" -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" smoke -PnewVersion="${pipelineVersion}" -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: runE2eTests {{{
# Given [APPLICATION_URL] will run the tests via [e2e] task
function runE2eTests() {
	local pipelineVersion="${PASSED_PIPELINE_VERSION:-${PIPELINE_VERSION:-}}"
	local applicationUrl="${APPLICATION_URL}"
	echo "Running e2e tests for application with url [${applicationUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" e2e -PnewVersion="${pipelineVersion}" -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${GRADLEW_BIN}" e2e -PnewVersion="${pipelineVersion}" -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: outputFolder {{{
# Gradle implementation of output folder
function outputFolder() {
	echo "build/libs"
} # }}}

# FUNCTION: testResultsAntPattern {{{
# Gradle implementation of test results ant pattern
function testResultsAntPattern() {
	echo "**/test-results/**/*.xml"
} # }}}

export -f build
export -f retrieveAppName
export -f retrieveGroupId
export -f executeApiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern

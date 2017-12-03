#!/bin/bash

set -e

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
}

function apiCompatibilityCheck() {
	# Find latest prod version
	local prodTag="${PASSED_LATEST_PROD_TAG:-${LATEST_PROD_TAG:-}}"
	[[ -z "${prodTag}" ]] && prodTag="$(findLatestProdTag)"
	echo "Last prod tag equals [${prodTag}]"
	if [[ -z "${prodTag}" ]]; then
		echo "No prod release took place - skipping this step"
	else
		# Downloading latest jar
		LATEST_PROD_VERSION=${prodTag#prod/}
		echo "Last prod version equals [${LATEST_PROD_VERSION}]"
		if [[ "${CI}" == "CONCOURSE" ]]; then
			# shellcheck disable=SC2086
			"${GRADLEW_BIN}" clean apiCompatibility -DlatestProductionVersion="${LATEST_PROD_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS} || (printTestResults && return 1)
		else
			# shellcheck disable=SC2086
			"${GRADLEW_BIN}" clean apiCompatibility -DlatestProductionVersion="${LATEST_PROD_VERSION}" -DREPO_WITH_BINARIES="${REPO_WITH_BINARIES_FOR_UPLOAD}" --stacktrace ${BUILD_OPTIONS}
		fi
	fi
}

function retrieveGroupId() {
	"${GRADLEW_BIN}" groupId -q | tail -1
}

function retrieveAppName() {
	"${GRADLEW_BIN}" artifactId -q | tail -1
}

function printTestResults() {
	# shellcheck disable=SC1117
	echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$(testResultsAntPattern)"
}

function retrieveStubRunnerIds() {
	"${GRADLEW_BIN}" stubIds -q | tail -1
}

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
}

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
}

function outputFolder() {
	echo "build/libs"
}

function testResultsAntPattern() {
	echo "**/test-results/**/*.xml"
}

export -f build
export -f apiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern

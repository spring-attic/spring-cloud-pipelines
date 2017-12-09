#!/bin/bash

set -e

export MAVENW_BIN
MAVENW_BIN="${MAVENW_BIN:-./mvnw}"

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
	# Required by settings.xml
	BUILD_OPTIONS="${BUILD_OPTIONS} -DM2_SETTINGS_REPO_ID=${M2_SETTINGS_REPO_ID} -DM2_SETTINGS_REPO_USERNAME=${M2_SETTINGS_REPO_USERNAME} -DM2_SETTINGS_REPO_PASSWORD=${M2_SETTINGS_REPO_PASSWORD}"
	# shellcheck disable=SC2086
	"${MAVENW_BIN}" org.codehaus.mojo:versions-maven-plugin:2.3:set -DnewVersion="${pipelineVersion}" ${BUILD_OPTIONS} || (echo "Build failed!!!" && return 1)
	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS}
	fi
}

function apiCompatibilityCheck() {
	local prodTag="${PASSED_LATEST_PROD_TAG:-${LATEST_PROD_TAG:-}}"
	[[ -z "${prodTag}" ]] && prodTag="$(findLatestProdTag)"
	echo "Last prod tag equals [${prodTag}]"
	if [[ -z "${prodTag}" ]]; then
		echo "No prod release took place - skipping this step"
	else
		# Putting env vars to output properties file for parameter passing
		export PASSED_LATEST_PROD_TAG="${prodTag}"
		local fileLocation="${OUTPUT_FOLDER}/test.properties"
		mkdir -p "${OUTPUT_FOLDER}"
		echo "PASSED_LATEST_PROD_TAG=${prodTag}" >>"${fileLocation}"
		# Downloading latest jar
		LATEST_PROD_VERSION=${prodTag#prod/}
		echo "Last prod version equals [${LATEST_PROD_VERSION}]"
		if [[ "${CI}" == "CONCOURSE" ]]; then
			# shellcheck disable=SC2086
			"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${LATEST_PROD_VERSION}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS} || (printTestResults && return 1)
		else
			# shellcheck disable=SC2086
			"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${LATEST_PROD_VERSION}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS}
		fi
	fi
}

# The function uses Maven Wrapper - if you're using Maven you have to have it on your classpath
# and change this function
function extractMavenProperty() {
	local prop="${1}"
	MAVEN_PROPERTY=$("${MAVENW_BIN}" -q  \
 -Dexec.executable="echo"  \
 -Dexec.args="\${${prop}}"  \
 --non-recursive  \
 org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
	# In some spring cloud projects there is info about deactivating some stuff
	MAVEN_PROPERTY=$(echo "${MAVEN_PROPERTY}" | tail -1)
	# In Maven if there is no property it prints out ${propname}
	if [[ "${MAVEN_PROPERTY}" == "\${${prop}}" ]]; then
		echo ""
	else
		echo "${MAVEN_PROPERTY}"
	fi
}

function retrieveGroupId() {
	{
		ruby -r rexml/document  \
 -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/groupId"].text' pom.xml  \
 || "${MAVENW_BIN}" org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
 -Dexpression=project.groupId | grep -Ev '(^\[|Download\w+:)'
	} | tail -1
}

function retrieveAppName() {
	{
		ruby -r rexml/document  \
 -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/artifactId"].text' pom.xml  \
 || "${MAVENW_BIN}" org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
 -Dexpression=project.artifactId | grep -Ev '(^\[|Download\w+:)'
	} | tail -1
}

function printTestResults() {
	# shellcheck disable=SC1117
	echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$(testResultsAntPattern)"
}

function retrieveStubRunnerIds() {
	extractMavenProperty 'stubrunner.ids'
}

function runSmokeTests() {
	local applicationUrl="${APPLICATION_URL}"
	local stubrunnerUrl="${STUBRUNNER_URL}"
	echo "Running smoke tests. Application url [${applicationUrl}], Stubrunner Url [${stubrunnerUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean install -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean install -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS}
	fi
}

function runE2eTests() {
	local applicationUrl="${APPLICATION_URL}"
	echo "Running e2e tests for application with url [${applicationUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean install -Pe2e -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean install -Pe2e -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS}
	fi
}

function outputFolder() {
	echo "target"
}

function testResultsAntPattern() {
	echo "**/surefire-reports/*"
}

export -f build
export -f apiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern

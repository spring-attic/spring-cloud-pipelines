#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Contains all Maven related build functions
# }}}

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

# FUNCTION: build {{{
# Maven implementation of build. Sets version, passes build options and distribution management properties.
# Uses [PIPELINE_VERSION], [PASSED_PIPELINE_VERSION] and [M2_SETTINGS...], [REPO_WITH_BINARIES...] related env vars
function build() {
	local pipelineVersion="${PASSED_PIPELINE_VERSION:-${PIPELINE_VERSION:-}}"
	# Required by settings.xml
	BUILD_OPTIONS="${BUILD_OPTIONS} -DM2_SETTINGS_REPO_ID=${M2_SETTINGS_REPO_ID} -DM2_SETTINGS_REPO_USERNAME=${M2_SETTINGS_REPO_USERNAME} -DM2_SETTINGS_REPO_PASSWORD=${M2_SETTINGS_REPO_PASSWORD}"
	# shellcheck disable=SC2086
	"${MAVENW_BIN}" versions:set -DnewVersion="${pipelineVersion}" -DprocessAllModules ${BUILD_OPTIONS} || (echo "Build failed!!!" && return 1)
	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: executeApiCompatibilityCheck {{{
# Maven implementation of executing API compatibility check
function executeApiCompatibilityCheck() {
	local latestProdVersion="${1}"
	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${latestProdVersion}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${latestProdVersion}" -Drepo.with.binaries="${REPO_WITH_BINARIES}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: extractMavenProperty {{{
# The function uses Maven Wrapper to extract property with name $1
#
# $1 - name of the property to extract
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
} # }}}

# FUNCTION: retrieveGroupId {{{
# Maven implementation of group id retrieval. First tries to use [ruby] to extract the
# group id, if that's not possible uses Maven to do it. Requires path $1 to pom.xml
#
# $1 - path to pom.xml
function retrieveGroupId() {
	local path
	path="${1:-.}"
	{
		ruby -r rexml/document  \
 -e 'parsed = REXML::Document.new(File.new(ARGV.shift)); puts (parsed.elements["/project/groupId"].nil? ? parsed.elements["/project/parent/groupId"].text : parsed.elements["/project/groupId"].text)' "${path}"/pom.xml | tail -1  \
 || "${MAVENW_BIN}" org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
 -Dexpression=project.groupId -f "${path}"/pom.xml  | grep -Ev '(^\[|Download\w+:)'
	} | tail -1
} # }}}

# FUNCTION: retrieveAppName {{{
# For the given main module (if [getMainModulePath] function exists, it will return the path
# to the main module), will use [ruby] if possible to return the application name. If that
# doesn't bring a result, will use Maven to extract the artifact id.
#
# $1 - path to main module
function retrieveAppName() {
	local path
	local mainModule
	# checks if the getMainModulePath function is defined. If not will just pick the current folder as main module
	if [ -n "$(type -t getMainModulePath)" ] && [ "$(type -t getMainModulePath)" = function ]; then
		mainModule="$( getMainModulePath )"
	else
		mainModule="."
	fi
	path="${1:-${mainModule:-.}}"
	{
		ruby -r rexml/document  \
 -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/artifactId"].text' "${path}"/pom.xml | tail -1 \
 || "${MAVENW_BIN}" org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
 -Dexpression=project.artifactId -f "${path}"/pom.xml  | grep -Ev '(^\[|Download\w+:)'
	} | grep -Ev '(^\[|Error\w+:)' | tail -1
} # }}}

# FUNCTION: printTestResults {{{
# Prints test results. Used by Concourse.
function printTestResults() {
	# shellcheck disable=SC1117
	echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$(testResultsAntPattern)"
} # }}}

# FUNCTION: retrieveStubRunnerIds {{{
# Extracts the stub runner ids from the Maven properties
function retrieveStubRunnerIds() {
	extractMavenProperty 'stubrunner.ids'
} # }}}

# FUNCTION: runSmokeTests {{{
# Given [APPLICATION_URL] and [STUBRUNNER_URL] will run the tests with [smoke] profile
function runSmokeTests() {
	local applicationUrl="${APPLICATION_URL}"
	local stubrunnerUrl="${STUBRUNNER_URL}"
	echo "Running smoke tests. Application url [${applicationUrl}], Stubrunner Url [${stubrunnerUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean test -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean test -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: runE2eTests {{{
# Given [APPLICATION_URL] will run the tests with [e2e] profile
function runE2eTests() {
	local applicationUrl="${APPLICATION_URL}"
	echo "Running e2e tests for application with url [${applicationUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean test -Pe2e -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		# shellcheck disable=SC2086
		"${MAVENW_BIN}" clean test -Pe2e -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS}
	fi
} # }}}

# FUNCTION: outputFolder {{{
# Maven implementation of output folder
function outputFolder() {
	echo "target"
} # }}}

# FUNCTION: testResultsAntPattern {{{
# Maven implementation of test results ant pattern
function testResultsAntPattern() {
	echo "**/surefire-reports/*"
} # }}}

export -f build
export -f retrieveAppName
export -f retrieveGroupId
export -f executeApiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern

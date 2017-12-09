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
	echo "Additional Build Options [${BUILD_OPTIONS}]"

	"${MAVENW_BIN}" org.codehaus.mojo:versions-maven-plugin:2.3:set -DnewVersion="${PIPELINE_VERSION}" "${BUILD_OPTIONS}" || (echo "Build failed!!!" && return 1)
	if [[ "${CI}" == "CONCOURSE" ]]; then
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES_FOR_UPLOAD}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		"${MAVENW_BIN}" clean verify deploy -Ddistribution.management.release.id="${M2_SETTINGS_REPO_ID}" -Ddistribution.management.release.url="${REPO_WITH_BINARIES_FOR_UPLOAD}" -Drepo.with.binaries="${REPO_WITH_BINARIES_FOR_UPLOAD}" ${BUILD_OPTIONS}
	fi
}

function apiCompatibilityCheck() {
	echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."

	# Find latest prod version
	[[ -z "${LATEST_PROD_TAG}" ]] && LATEST_PROD_TAG="$(findLatestProdTag)"
	echo "Last prod tag equals ${LATEST_PROD_TAG}"
	if [[ -z "${LATEST_PROD_TAG}" ]]; then
		echo "No prod release took place - skipping this step"
	else
		# Downloading latest jar
		LATEST_PROD_VERSION=${LATEST_PROD_TAG#prod/}
		echo "Last prod version equals [${LATEST_PROD_VERSION}]"
		echo "Additional Build Options [${BUILD_OPTIONS}]"
		if [[ "${CI}" == "CONCOURSE" ]]; then
			"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${LATEST_PROD_VERSION}" -Drepo.with.binaries="${REPO_WITH_BINARIES_FOR_UPLOAD}" ${BUILD_OPTIONS} || (printTestResults && return 1)
		else
			"${MAVENW_BIN}" clean verify -Papicompatibility -Dlatest.production.version="${LATEST_PROD_VERSION}" -Drepo.with.binaries="${REPO_WITH_BINARIES_FOR_UPLOAD}" ${BUILD_OPTIONS}
		fi
	fi
}

# The function uses Maven Wrapper - if you're using Maven you have to have it on your classpath
# and change this function
function extractMavenProperty() {
	local prop="${1}"
	MAVEN_PROPERTY=$("${MAVENW_BIN}" ${BUILD_OPTIONS} -q  \
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
 || "${MAVENW_BIN}" ${BUILD_OPTIONS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
 -Dexpression=project.groupId | grep -Ev '(^\[|Download\w+:)'
	} | tail -1
}

function retrieveAppName() {
	{
		ruby -r rexml/document  \
 -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/artifactId"].text' pom.xml  \
 || "${MAVENW_BIN}" ${BUILD_OPTIONS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate  \
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
		"${MAVENW_BIN}" clean install -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
		"${MAVENW_BIN}" clean install -Psmoke -Dapplication.url="${applicationUrl}" -Dstubrunner.url="${stubrunnerUrl}" ${BUILD_OPTIONS}
	fi
}

function runE2eTests() {
	local applicationUrl="${APPLICATION_URL}"
	echo "Running e2e tests for application with url [${applicationUrl}]"

	if [[ "${CI}" == "CONCOURSE" ]]; then
		"${MAVENW_BIN}" clean install -Pe2e -Dapplication.url="${applicationUrl}" ${BUILD_OPTIONS} || (printTestResults && return 1)
	else
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

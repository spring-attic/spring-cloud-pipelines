#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Contains all NPM related build functions
# }}}

export NPM_BIN NODE_BIN
NPM_BIN="${NPM_BIN:-npm}"
NODE_BIN="${NODE_BIN:-node}"
APT_BIN="${APT_BIN:-apt-get}"
CURL_BIN="${CURL_BIN:-curl}"
SUDO_BIN="${SUDO_BIN:-sudo}"

# ---- BUILD PHASE ----

# FUNCTION: build {{{
# npm implementation of the build function.
# Requires [npm] and [node]. Installs those if possible
function build() {
	downloadNpmIfMissing
	"${NPM_BIN}" install
	"${NPM_BIN}" run test
} # }}}

# FUNCTION: downloadAppBinary {{{
# Just downloads the npm libraries. We will use sources
function downloadAppBinary() {
	echo "Nothing to download - will call npm install to speed things up"
	"${NPM_BIN}" install
} # }}}

# FUNCTION: executeApiCompatibilityCheck {{{
# npm implementation of the execute API compatibility check
function executeApiCompatibilityCheck() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-apicompatibility
} # }}}

# FUNCTION: retrieveGroupId {{{
# npm implementation of the retrieve group id
function retrieveGroupId() {
	downloadNpmIfMissing
	"${NPM_BIN}" run group-id 2>/dev/null | tail -1
} # }}}

# FUNCTION: retrieveAppName {{{
# npm implementation of the retrieve app name
function retrieveAppName() {
	if [[ "${PROJECT_NAME}" != "" && "${PROJECT_NAME}" != "${DEFAULT_PROJECT_NAME}" ]]; then
		echo "${PROJECT_NAME}"
	else
		downloadNpmIfMissing
		"${NPM_BIN}" run app-name 2>/dev/null | tail -1
	fi
} # }}}

# FUNCTION: retrieveStubRunnerIds {{{
# npm implementation of the retrieve stub runner ids
function retrieveStubRunnerIds() {
	downloadNpmIfMissing
	"${NPM_BIN}" run stub-ids 2>/dev/null | tail -1
} # }}}

# ---- TEST PHASE ----

# FUNCTION: runSmokeTests {{{
# npm implementation of the run smoke tests
function runSmokeTests() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-smoke
} # }}}

# ---- STAGE PHASE ----

# FUNCTION: runE2eTests {{{
# npm implementation of the e2e tests
function runE2eTests() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-e2e
} # }}}

# ---- COMMON ----

# FUNCTION: projectType {{{
# npm implementation of the project type
function projectType() {
	echo "NPM"
} # }}}

# FUNCTION: projectType {{{
# npm implementation of the output folder
function outputFolder() {
	echo "target"
} # }}}

# FUNCTION: projectType {{{
# npm implementation of the test results ant pattern
function testResultsAntPattern() {
	echo ""
} # }}}

# ---- NPM SPECIFIC ----


# FUNCTION: downloadNpmIfMissing {{{
# Downloads and installs node and npm if missing
function downloadNpmIfMissing() {
	installNodeIfMissing
	local npmInstalled
	"${NPM_BIN}" --version > /dev/null 2>&1 && npmInstalled="true" || npmInstalled="false"
	if [[ "${npmInstalled}" == "false" ]]; then
		"${CURL_BIN}" -L https://www.npmjs.com/install.sh | sh  > /dev/null 2>&1
	fi
} # }}}

# FUNCTION: downloadNpmIfMissing {{{
# Installs node if missing
function installNodeIfMissing() {
	local nodeInstalled
	"${NODE_BIN}" --version > /dev/null 2>&1 && nodeInstalled="true" || nodeInstalled="false"
	if [[ "${nodeInstalled}" == "false" ]]; then
		# LAME
		export LANG=C.UTF-8
		"${CURL_BIN}" -sL https://deb.nodesource.com/setup_10.x | "${SUDO_BIN}" -E bash -  > /dev/null 2>&1
		"${SUDO_BIN}" "${APT_BIN}" install -y nodejs  > /dev/null 2>&1
	fi
} # }}}

export ARTIFACT_TYPE
ARTIFACT_TYPE="${SOURCE_ARTIFACT_TYPE_NAME}"

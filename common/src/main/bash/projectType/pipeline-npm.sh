#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

export NPM_BIN NODE_BIN
NPM_BIN="${NPM_BIN:-npm}"
NODE_BIN="${NODE_BIN:-node}"
APT_BIN="${APT_BIN:-apt-get}"
CURL_BIN="${CURL_BIN:-curl}"
SUDO_BIN="${SUDO_BIN:-sudo}"

# ---- BUILD PHASE ----
function build() {
	downloadNpmIfMissing
	"${NPM_BIN}" install
	"${NPM_BIN}" run test
}

function downloadAppBinary() {
	echo "Nothing to download - will call npm install to speed things up"
	"${NPM_BIN}" install
}

function executeApiCompatibilityCheck() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-apicompatibility
}

function retrieveGroupId() {
	downloadNpmIfMissing
	"${NPM_BIN}" run group-id 2>/dev/null | tail -1
}

function retrieveAppName() {
	if [[ "${PROJECT_NAME}" != "" && "${PROJECT_NAME}" != "${DEFAULT_PROJECT_NAME}" ]]; then
		echo "${PROJECT_NAME}"
	else
		downloadNpmIfMissing
		"${NPM_BIN}" run app-name 2>/dev/null | tail -1
	fi
}

# ---- TEST PHASE ----

function runSmokeTests() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-smoke
}

# ---- STAGE PHASE ----

function runE2eTests() {
	downloadNpmIfMissing
	"${NPM_BIN}" run test-e2e
}

# ---- COMMON ----

function projectType() {
	echo "NPM"
}

function outputFolder() {
	echo "target"
}

function testResultsAntPattern() {
	echo ""
}

# ---- NPM SPECIFIC ----

function downloadNpmIfMissing() {
	installNodeIfMissing
	local npmInstalled
	"${NPM_BIN}" --version > /dev/null 2>&1 && npmInstalled="true" || npmInstalled="false"
	if [[ "${npmInstalled}" == "false" ]]; then
		"${CURL_BIN}" -L https://www.npmjs.com/install.sh | sh  > /dev/null 2>&1
	fi
}

function installNodeIfMissing() {
	local nodeInstalled
	"${NODE_BIN}" --version > /dev/null 2>&1 && nodeInstalled="true" || nodeInstalled="false"
	if [[ "${nodeInstalled}" == "false" ]]; then
		# LAME
		export LANG=C.UTF-8
		"${CURL_BIN}" -sL https://deb.nodesource.com/setup_10.x | "${SUDO_BIN}" -E bash -  > /dev/null 2>&1
		"${SUDO_BIN}" "${APT_BIN}" install -y nodejs  > /dev/null 2>&1
	fi
}

export ARTIFACT_TYPE
ARTIFACT_TYPE="${SOURCE_ARTIFACT_TYPE_NAME}"

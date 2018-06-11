#!/usr/bin/env bash

# ---- BUILD PHASE ----
function build() {
	echo "build $*"
}

function apiCompatibilityCheck() {
	echo "apiCompatibilityCheck $*"
}

# ---- TEST PHASE ----

function testDeploy() {
	echo "testDeploy $*"
}

function testRollbackDeploy() {
	echo "testRollbackDeploy $*"
}

function prepareForSmokeTests() {
	echo "prepareForSmokeTests $*"
}

function runSmokeTests() {
	echo "runSmokeTests $*"
}

# ---- STAGE PHASE ----

function stageDeploy() {
	echo "stageDeploy $*"
}

function prepareForE2eTests() {
	echo "prepareForE2eTests $*"
}

function runE2eTests() {
	echo "runE2eTests $*"
}

# ---- PRODUCTION PHASE ----

function prodDeploy() {
	echo "prodDeploy $*"
}

function rollbackToPreviousVersion() {
	echo "rollbackToPreviousVersion $*"
}

function completeSwitchOver() {
	echo "completeSwitchOver $*"
}

# ---- COMMON ----

function projectType() {
	echo "projectType $*"
}

function outputFolder() {
	echo "outputFolder $*"
}

function testResultsAntPattern() {
	echo "testResultsAntPattern $*"
}

echo "EXECUTED SCRIPT"

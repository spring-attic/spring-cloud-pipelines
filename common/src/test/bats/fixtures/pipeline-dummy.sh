#!/bin/bash
function retrieveGroupId() {
	echo "com.example"
}

function retrieveAppName() {
    echo "${PROJECT_NAME}"
}

function retrieveStubRunnerIds() {
    echo "com.example:foo:1.0.0.RELEASE:stubs:1234"
}

function deleteService() {
    echo "$*"
}

function deployService() {
    echo "$*" 
}

function outputFolder() {
    echo "target/"
}

function testResultsAntPattern() {
    echo "**/test-results/*.xml"
}

# ---- BUILD PHASE ----
function build() {
    echo "build"
}

function executeApiCompatibilityCheck() {
    echo "executeApiCompatibilityCheck"
}

# ---- TEST PHASE ----

function testDeploy() {
    echo "testDeploy"
}

function testRollbackDeploy() {
    echo "testRollbackDeploy [${1}]"
}

function prepareForSmokeTests() {
    echo "prepareForSmokeTests"
}

function runSmokeTests() {
    echo "runSmokeTests"
}

# ---- STAGE PHASE ----

function stageDeploy() {
    echo "stageDeploy"
}

function prepareForE2eTests() {
    echo "prepareForE2eTests"
}

function runE2eTests() {
    echo "runE2eTests"
}

# ---- PRODUCTION PHASE ----

function prodDeploy() {
    echo "prodDeploy"
}

function completeSwitchOver() {
    echo "completeSwitchOver"
}

function rollbackToPreviousVersion() {
    echo "rollbackToPreviousVersion"
}

export -f retrieveGroupId
export -f retrieveAppName
export -f deleteService
export -f deployService
export -f outputFolder
export -f testResultsAntPattern
export -f testDeploy
export -f testRollbackDeploy
export -f prepareForSmokeTests
export -f runSmokeTests
export -f stageDeploy
export -f prepareForE2eTests
export -f runE2eTests
export -f prodDeploy
export -f completeSwitchOver
export -f rollbackToPreviousVersion

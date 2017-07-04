#!/bin/bash
set -e

# ---- BUILD PHASE ----
function build() {
    echo "Build the application and produce a binary. Most likely you'll
        upload that binary somewhere"
    exit 1
}

function apiCompatibilityCheck() {
    echo "Execute api compatibility check step"
    exit 1
}

# ---- TEST PHASE ----

function testDeploy() {
    echo "Deploy binaries and required services to test environment"
    exit 1
}

function testRollbackDeploy() {
    echo "Deploy binaries and required services to test environment for rollback testing"
    exit 1
}

function prepareForSmokeTests() {
    echo "Prepares environment for smoke tests"
    exit 1
}

function runSmokeTests() {
    echo "Executes smoke tests "
    exit 1
}

# ---- STAGE PHASE ----

function stageDeploy() {
    echo "Deploy binaries and required services to stage environment"
    exit 1
}

function prepareForE2eTests() {
    echo "Prepares the environment for end to end tests. Most likely will download
    some binaries and upload them to the environment"
    exit 1
}

function runE2eTests() {
    echo "Executes end to end tests"
    exit 1
}

# ---- PRODUCTION PHASE ----

function performGreenDeployment() {
    echo "Will deploy the Green binary next to the Blue one, on the production environment"
    exit 1
}

function deleteBlueInstance() {
    echo "Deletes the old, Blue binary from the production environment"
    exit 1
}

# ---- COMMON ----

function projectType() {
    echo "Returns the type of the project basing on the cloned sources.
    Example: MAVEN, GRADLE etc."
    exit 1
}

function outputFolder() {
    echo "Returns the folder where the built binary will be stored.
    Example: 'target/' - for Maven, 'build/' - for Gradle etc."
    exit 1
}

function testResultsAntPattern() {
    echo "Returns the ant pattern for the test results.
    Example: '**/test-results/*.xml' - for Maven, '**/surefire-reports/*' - for Gradle etc."
    exit 1
}

# Finds the latest prod tag from git
function findLatestProdTag() {
    local LAST_PROD_TAG=$(git for-each-ref --sort=taggerdate --format '%(refname)' refs/tags/prod | head -n 1)
    LAST_PROD_TAG=${LAST_PROD_TAG#refs/tags/}
    echo "${LAST_PROD_TAG}"
}

# Extracts the version from the production tag
function extractVersionFromProdTag() {
    local tag="${1}"
    LAST_PROD_VERSION=${tag#prod/}
    echo "${LAST_PROD_VERSION}"
}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CURRENTLY WE ONLY SUPPORT CF AS PAAS OUT OF THE BOX
export PAAS_TYPE="${PAAS_TYPE:-cf}"

echo "Picked PAAS is [${PAAS_TYPE}]"
echo "Current environment is [${ENVIRONMENT}]"

[[ -f "${__DIR}/pipeline-${PAAS_TYPE}.sh" ]] && source "${__DIR}/pipeline-${PAAS_TYPE}.sh" || \
    echo "No pipeline-${PAAS_TYPE}.sh found"

export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsAntPattern )

echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"
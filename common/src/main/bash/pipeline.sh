#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

IFS=$' \n\t'

__ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
    echo "Prepares environment for smoke tests. Retrieves the latest production
    tags, exports all URLs required for smoke tests, etc."
    exit 1
}

function runSmokeTests() {
    echo "Executes smoke tests. Profits from env vars set by 'prepareForSmokeTests'"
    exit 1
}

# ---- STAGE PHASE ----

function stageDeploy() {
    echo "Deploy binaries and required services to stage environment"
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
    local LAST_PROD_TAG
    LAST_PROD_TAG=$( git for-each-ref --sort=taggerdate --format '%(refname)' refs/tags/prod | head -n 1 )
    echo "${LAST_PROD_TAG#refs/tags/}"
}

# Extracts the version from the production tag
function extractVersionFromProdTag() {
    local tag="${1}"
    echo "${tag#prod/}"
}

# Checks for existence of pipeline.yaml file that contains types and names of the
# services required to be deployed for the given environment
function pipelineDescriptorExists() {
    if [ -f "pipeline.yml" ]
    then
        echo "true"
    else
        echo "false"
    fi
}

function deleteService() {
    local serviceType="${1}"
    local serviceName="${2}"
    echo "Should delete a service of type [${serviceType}] and name [${serviceName}]
    Example: deleteService mysql foo-mysql"
    exit 1
}

function deployService() {
    local serviceType="${1}"
    local serviceName="${2}"
    local serviceCoordinates="${3}"
    echo "Should deploy a service of type [${serviceType}], name [${serviceName}] and coordinates [${serviceCoordinates}]
    Example: deployService eureka foo-eureka groupid:artifactid:1.0.0.RELEASE"
    exit 1
}

function serviceExists() {
    local serviceType="${1}"
    local serviceName="${2}"
    echo "Should check if a service of type [${serviceType}] and name [${serviceName}] exists
    Example: serviceExists mysql foo-mysql
    Returns: 'true' if service exists and 'false' if it doesn't"
    exit 1
}

# Deploys services assuming that pipeline descriptor exists
# For TEST environment first deletes, then deploys services
# For other environments only deploys a service if it wasn't there.
# Uses ruby and jq
function deployServices() {
    if [[ "$( pipelineDescriptorExists )" != "true" ]]; then
        echo "No pipeline descriptor found - will not deploy any services"
        return
    fi

    PARSED_YAML=$( yaml2json "pipeline.yml" )
    export PARSED_YAML

    while read -r serviceType serviceName serviceCoordinates; do
        if [[ "${ENVIRONMENT}" == "TEST" ]]; then
            deleteService "${serviceType}" "${serviceName}"
            deployService "${serviceType}" "${serviceName}" "${serviceCoordinates}"
        else
            if [[ "$( serviceExists "${serviceName}" )" == "true" ]]; then
                echo "Skipping deployment since service is already deployed"
            else
                deployService "${serviceType}" "${serviceName}" "${serviceCoordinates}"
            fi
        fi
    # retrieve the space separated type, name and coordinates
    done <<< "$( echo "${PARSED_YAML}" | \
                 jq -r --arg x "${ENVIRONMENT}" '.[$x | ascii_downcase].services[] | "\(.type) \(.name) \(.coordinates)"' )"
}

# Converts YAML to JSON - uses ruby
function yaml2json() {
    ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' "$@"
}

# Converts a string to lower case
function toLowerCase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# CURRENTLY WE ONLY SUPPORT CF AS PAAS OUT OF THE BOX
PAAS_TYPE="${PAAS_TYPE:-cf}"
export PAAS_TYPE

echo "Picked PAAS is [${PAAS_TYPE}]"
echo "Current environment is [${ENVIRONMENT}]"

# shellcheck source=/dev/null
[[ -f "${__ROOT}/pipeline-${PAAS_TYPE}.sh" ]] && source "${__ROOT}/pipeline-${PAAS_TYPE}.sh" || \
    echo "No pipeline-${PAAS_TYPE}.sh found"

OUTPUT_FOLDER="$( outputFolder )"
TEST_REPORTS_FOLDER="$( testResultsAntPattern )"

export OUTPUT_FOLDER TEST_REPORTS_FOLDER

echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

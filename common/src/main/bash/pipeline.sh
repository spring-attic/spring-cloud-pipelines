#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

IFS=$' \n\t'

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

function prepareForE2eTests() {
	echo "Prepares environment for smoke tests. Logs in to PAAS etc."
	exit 1
}

function runE2eTests() {
	echo "Executes end to end tests. Profits from env vars set by 'prepareForE2eTests'"
	exit 1
}

# ---- PRODUCTION PHASE ----

function prodDeploy() {
	echo "Will deploy the Green binary next to the Blue one, on the production environment"
	exit 1
}

function rollbackToPreviousVersion() {
	echo "Will rollback to blue instance"
	exit 1
}

function completeSwitchOver() {
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
	local prodTag="${PASSED_LATEST_PROD_TAG:-${LATEST_PROD_TAG:-}}"
	if [[ ! -z "${prodTag}" ]]; then
		echo "${prodTag}"
	else
		local latestProdTag
		latestProdTag=$("${GIT_BIN}" for-each-ref --sort=taggerdate --format '%(refname)' refs/tags/prod | tail -1)
		export LATEST_PROD_TAG PASSED_LATEST_PROD_TAG
		LATEST_PROD_TAG="${latestProdTag#refs/tags/}"
		PASSED_LATEST_PROD_TAG="${LATEST_PROD_TAG}"
		echo "${LATEST_PROD_TAG}"
	fi
}

# Extracts the version from the production tag
function extractVersionFromProdTag() {
	local tag="${1}"
	echo "${tag#prod/}"
}

# TODO: maybe don't need this if space is created anew for test????
function deleteService() {
	local serviceName="${1}"
	local serviceType="${2}"
	echo "Should delete a service with name [${serviceName}] and type [${serviceType}]
	Example: deleteService foo-eureka eureka"
	exit 1
}

function deployService() {
	local serviceName="${1}"
	local serviceType="${2}"
	echo "Should deploy a service with name [${serviceName}] and type [${serviceType}]
	Example: deployService foo-eureka eureka"
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

# Sets the environment variable with contents of the parsed pipeline descriptor
# shellcheck disable=SC2120
function parsePipelineDescriptor() {
	if [[ ! -f "${PIPELINE_DESCRIPTOR}" ]]; then
		echo "No pipeline descriptor found - will not deploy any services"
		return
	fi
	export PARSED_YAML
	PARSED_YAML=$(yaml2json "${PIPELINE_DESCRIPTOR}")
}

# Deploys services assuming that pipeline descriptor exists
# For TEST environment first deletes, then deploys services
# For other environments only deploys a service if it wasn't there.
# Uses ruby and jq
function deployServices() {

	# shellcheck disable=SC2119
	parsePipelineDescriptor

	if [[ -z "${PARSED_YAML}" ]]; then
		return
	fi

	while read -r serviceName serviceType useExisting; do
	    serviceType=$(toLowerCase "${serviceType}")
		if [[ "${ENVIRONMENT}" == "TEST" && "${useExisting}" != "true" ]]; then
			deleteService "${serviceName}" "${serviceType}"
			deployService "${serviceName}" "${serviceType}"
		else
			if [[ "$(serviceExists "${serviceName}")" == "true" ]]; then
				echo "Skipping deployment since service is already deployed"
			else
				deployService "${serviceName}" "${serviceType}"
			fi
		fi
	# retrieve the space separated name and type
	done <<<"$(echo "${PARSED_YAML}" | \
				 jq -r --arg x "${LOWERCASE_ENV}" '.[$x].services[] | "\(.name) \(.type) \(.useExisting)"')"
}

# Converts YAML to JSON - uses ruby
function yaml2json() {
	ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' "$@"
}

# Converts a string to lower case
function toLowerCase() {
	echo "$1" | tr '[:upper:]' '[:lower:]'
}

PAAS_TYPE="$( toLowerCase "${PAAS_TYPE:-cf}" )"
# Not every linux distribution comes with installation of JQ that is new enough
# to have the asci_downcase method. That's why we're using the global env variable
# At some point we'll deprecate this and use what JQ provides
LOWERCASE_ENV="$(toLowerCase "${ENVIRONMENT}")"

PIPELINE_DESCRIPTOR="${PIPELINE_DESCRIPTOR:-sc-pipelines.yml}"
GIT_BIN="${GIT_BIN:-git}"

export PIPELINE_DESCRIPTOR PAAS_TYPE LOWERCASE_ENV GIT_BIN

echo "Picked PAAS is [${PAAS_TYPE}]"
echo "Current environment is [${ENVIRONMENT}]"
# shellcheck source=/dev/null
[[ -f "${__ROOT}/pipeline-${PAAS_TYPE}.sh" ]] && source "${__ROOT}/pipeline-${PAAS_TYPE}.sh" ||  \
 echo "No pipeline-${PAAS_TYPE}.sh found"

OUTPUT_FOLDER="$(outputFolder)"
TEST_REPORTS_FOLDER="$(testResultsAntPattern)"

export OUTPUT_FOLDER TEST_REPORTS_FOLDER

echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

export CUSTOM_SCRIPT_IDENTIFIER="${CUSTOM_SCRIPT_IDENTIFIER:-custom}"
echo "Custom script identifier is [${CUSTOM_SCRIPT_IDENTIFIER}]"
CUSTOM_SCRIPT_DIR="${__ROOT}/${CUSTOM_SCRIPT_IDENTIFIER}"
mkdir -p "${__ROOT}/${CUSTOM_SCRIPT_IDENTIFIER}"
CUSTOM_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]}")"
echo "Path to custom script is [${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}]"
# shellcheck source=/dev/null
[[ -f "${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}" ]] && source "${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}" ||  \
 echo "No ${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME} found"

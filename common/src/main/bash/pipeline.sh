#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

IFS=$' \n\t'

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# ================================================================
#                      INTERFACES - START
# ================================================================

# ---- BUILD PHASE ----

# Build the application and produce a binary. Most likely you'll upload that binary somewhere
function build() {
	echo "Build the application and produce a binary. Most likely you'll
		upload that binary somewhere"
	exit 1
}

# Execute api compatibility check step
function apiCompatibilityCheck() {
	echo "Execute api compatibility check step"
	exit 1
}

# Echos the namespace that corresponds to the given application. In the
#	JVM world corresponds to a group id of a project
function retrieveGroupId() {
	echo "Echos the namespace that corresponds to the given application. In the
	JVM world corresponds to a group id of a project"
	exit 1
}

# Echos the name of the application
function retrieveAppName() {
	echo "Echos the name of the application"
	exit 1
}

# ---- TEST PHASE ----

# Deploy binaries and required services to test environment
function testDeploy() {
	echo "Deploy binaries and required services to test environment"
	exit 1
}

# Deploy binaries and required services to test environment for rollback testing
function testRollbackDeploy() {
	echo "Deploy binaries and required services to test environment for rollback testing"
	exit 1
}

# Prepares environment for smoke tests. Retrieves the latest production
#	tags, exports all URLs required for smoke tests, etc.
function prepareForSmokeTests() {
	echo "Prepares environment for smoke tests. Retrieves the latest production
	tags, exports all URLs required for smoke tests, etc."
	exit 1
}

# Executes smoke tests. Profits from env vars set by 'prepareForSmokeTests'
function runSmokeTests() {
	echo "Executes smoke tests. Profits from env vars set by 'prepareForSmokeTests'"
	exit 1
}

# ---- STAGE PHASE ----

# Deploy binaries and required services to stage environment
function stageDeploy() {
	echo "Deploy binaries and required services to stage environment"
	exit 1
}

# Prepares environment for smoke tests. Logs in to PAAS etc.
function prepareForE2eTests() {
	echo "Prepares environment for smoke tests. Logs in to PAAS etc."
	exit 1
}

# Executes end to end tests. Profits from env vars set by 'prepareForE2eTests'
function runE2eTests() {
	echo "Executes end to end tests. Profits from env vars set by 'prepareForE2eTests'"
	exit 1
}

# ---- PRODUCTION PHASE ----

# Will deploy the Green binary next to the Blue one, on the production environment
function prodDeploy() {
	echo "Will deploy the Green binary next to the Blue one, on the production environment"
	exit 1
}

# Will rollback to blue instance
function rollbackToPreviousVersion() {
	echo "Will rollback to blue instance"
	exit 1
}

# Deletes the old, Blue binary from the production environment
function completeSwitchOver() {
	echo "Deletes the old, Blue binary from the production environment"
	exit 1
}

# ---- DEPLOYMENT RELATED ---


# Contract for deleting a service
# @param {1} - service name
# @param {2} - service type
function deleteService() {
	local serviceName="${1}"
	local serviceType="${2}"
	echo "Should delete a service with name [${serviceName}] and type [${serviceType}]
	Example: deleteService foo-eureka eureka"
	exit 1
}

# Contract for deploying a single service
# @param {1} - service name
# @param {2} - service type
function deployService() {
	local serviceName="${1}"
	local serviceType="${2}"
	echo "Should deploy a service with name [${serviceName}] and type [${serviceType}]
	Example: deployService foo-eureka eureka"
	exit 1
}

# Contract for verification if a service exists
# @param {1} - service type
# @param {2} - service name
function serviceExists() {
	local serviceName="${2}"
	local serviceType="${1}"
	echo "Should check if a service of type [${serviceType}] and name [${serviceName}] exists
	Example: serviceExists mysql foo-mysql
	Returns: 'true' if service exists and 'false' if it doesn't"
	exit 1
}

# ---- COMMON ----

# Returns the type of the project basing on the cloned sources.
# Example: MAVEN, GRADLE etc.
function projectType() {
	echo "Returns the type of the project basing on the cloned sources.
	Example: MAVEN, GRADLE etc."
	exit 1
}

# Returns the folder where the built binary will be stored.
# Example: 'target/' - for Maven, 'build/' - for Gradle etc.
function outputFolder() {
	echo "Returns the folder where the built binary will be stored.
	Example: 'target/' - for Maven, 'build/' - for Gradle etc."
	exit 1
}

# Returns the ant pattern for the test results.
# Example: '**/test-results/*.xml' - for Maven, '**/surefire-reports/*' - for Gradle etc.
function testResultsAntPattern() {
	echo "Returns the ant pattern for the test results.
	Example: '**/test-results/*.xml' - for Maven, '**/surefire-reports/*' - for Gradle etc."
	exit 1
}

# ================================================================
#                      INTERFACES - END
# ================================================================


# ================================================================
#                  COMMON FUNCTIONS - START
# ================================================================

# Echoes the latest prod tag from git with trimmed refs part
function findLatestProdTag() {
	local prodTag="${PASSED_LATEST_PROD_TAG:-${LATEST_PROD_TAG:-}}"
	if [[ ! -z "${prodTag}" ]]; then
		echo "${prodTag}"
	else
		local latestProdTag
		latestProdTag="$(latestProdTagFromGit)"
		export LATEST_PROD_TAG PASSED_LATEST_PROD_TAG
		LATEST_PROD_TAG="$(trimRefsTag "${latestProdTag}")"
		PASSED_LATEST_PROD_TAG="${LATEST_PROD_TAG}"
		echo "${LATEST_PROD_TAG}"
	fi
}

# Extracts latest prod tag
function latestProdTagFromGit() {
	local latestProdTag
	latestProdTag=$("${GIT_BIN}" for-each-ref --sort=taggerdate --format '%(refname)' "refs/tags/prod/${PROJECT_NAME}" | tail -1)
	echo "${latestProdTag}"
}

# Extracts latest prod tag
function trimRefsTag() {
	local latestProdTag="${1}"
	echo "${latestProdTag#refs/tags/}"
}

# Extracts the version from the production tag
function extractVersionFromProdTag() {
	local tag="${1}"
	echo "${tag#prod/}"
}

# Sets the environment variable with contents of the parsed pipeline descriptor
# shellcheck disable=SC2120
function parsePipelineDescriptor() {
	export PIPELINE_DESCRIPTOR_PRESENT
	if [[ ! -f "${PIPELINE_DESCRIPTOR}" ]]; then
		echo "No pipeline descriptor found - will not deploy any services"
		PIPELINE_DESCRIPTOR_PRESENT="false"
		return
	fi
	PIPELINE_DESCRIPTOR_PRESENT="true"
	if [[ "${PARSED_YAML}" != "" ]]; then
		echo "Pipeline descriptor already parsed - will not parse it again"
	else
		export PARSED_YAML
		PARSED_YAML=$(yaml2json "${PIPELINE_DESCRIPTOR}")
	fi
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

	local nodeExists
	envNodeExists "${LOWERCASE_ENV}" && nodeExists="true" || nodeExists="false"
	if [[ "${nodeExists}" == "false" ]]; then
		echo "No services node present. Will skip deployment of services"
		return;
	fi

	while read -r serviceName serviceType useExisting; do
		local parsedServiceType
		parsedServiceType=$(toLowerCase "${serviceType}")
		# shellcheck disable=SC2153
		if [[ "${ENVIRONMENT}" == "TEST" && "${useExisting}" != "true" ]]; then
			deleteService "${serviceName}" "${parsedServiceType}"
			deployService "${serviceName}" "${parsedServiceType}"
		else
			if [[ "$(serviceExists "${serviceName}")" == "true" ]]; then
				echo "Skipping deployment since service is already deployed"
			else
				deployService "${serviceName}" "${parsedServiceType}"
			fi
		fi
	# retrieve the space separated name and type
	done <<<"$(echo "${PARSED_YAML}" | \
				 jq -r --arg x "${LOWERCASE_ENV}" '.[$x].services[] | "\(.name) \(.type) \(.useExisting)"')"
}

# Returns 0 if services node exists, 1 if it doesn't
function envNodeExists() {
	local environment="${1}"
	local services
	services="$(echo "${PARSED_YAML}" |  jq -r --arg x "${environment}" '.[$x]')"
	if [[ "${services}" == "null" || "${services}" == "" ]]; then
		return 1
	else
		return 0
	fi
}

# Converts YAML to JSON - uses ruby
function yaml2json() {
	ruby -ryaml -rjson -e 'puts JSON.pretty_generate(YAML.load(ARGF))' "$@"
}

# Converts a string to lower case
function toLowerCase() {
	echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Gets the build coordinates from descriptor
function getMainModulePath() {
	if [[ ! -z "${PARSED_YAML}" ]]; then
		local mainModule
		mainModule="$( echo "${PARSED_YAML}" | jq -r '.build.main_module' )"
		if [[ "${mainModule}" == "null" ]]; then
			mainModule=""
		fi
		echo "${mainModule}"
	else
		echo ""
	fi
}

# ================================================================
#                  COMMON FUNCTIONS - END
# ================================================================

# ================================================================
#           DEFINING PROJECT SETUP / LANGUAGE - START
# ================================================================
# Defines the project setup. Takes into consideration the location of the pipeline
# descriptor, project name, main module path etc.
function defineProjectSetup() {
	# if pipeline descriptor is in the provided folder that means that
	# we don't have a descriptor per application
	if [[ "${PIPELINE_DESCRIPTOR_PRESENT}" == "true" ]]; then
		echo "Pipeline descriptor found"
		mainModulePath="$( getMainModulePath )"
		if [[ "${mainModulePath}" != "" && "${mainModulePath}" != "null" ]]; then
			# multi module - has a coordinates section in the descriptor
			PROJECT_SETUP="MULTI_MODULE"
			echo "Build coordinates section found, project setup [${PROJECT_SETUP}], main module path [${mainModulePath}]"
		else
			# single repo - no coordinates
			PROJECT_SETUP="SINGLE_REPO"
			echo "No build coordinates section found, project setup [${PROJECT_SETUP}], main module path [${mainModulePath}]"
		fi
		ROOT_PROJECT_DIR="."
	else
		echo "Pipeline descriptor missing"
		# if pipeline descriptor is missing but a directory with name equal to PROJECT_NAME exists
		# that means that it's a multi-project and we need to cd to that folder
		if [[ -d "${PROJECT_NAME}" ]]; then
			echo "Project dir found [${PROJECT_NAME}]"
			cd "${PROJECT_NAME}"
			parsePipelineDescriptor
			mainModulePath="$( getMainModulePath )"
			if [[ "${mainModulePath}" != "" && "${mainModulePath}" != "null" ]]; then
				# multi project with module - has a coordinates section in the descriptor
				PROJECT_SETUP="MULTI_PROJECT_WITH_MODULES"
				echo "Build coordinates section found, project setup [${PROJECT_SETUP}], main module path [${mainModulePath}]"
			else
				# multi project without modules
				PROJECT_SETUP="MULTI_PROJECT"
				echo "No build coordinates section found, project setup [${PROJECT_SETUP}], main module path [${mainModulePath}]"
			fi
			ROOT_PROJECT_DIR="${PROJECT_NAME}"
		else
			# No descriptor and no module is present - will treat it as a single repo with no descriptor
			PROJECT_SETUP="SINGLE_REPO"
			echo "No descriptor or module found for project with name [${PROJECT_NAME}], project setup [${PROJECT_SETUP}]"
			ROOT_PROJECT_DIR="."
		fi
	fi
}

# ================================================================
#                      EXPORTS AND CONSTANTS
# ================================================================
export PIPELINE_DESCRIPTOR PAAS_TYPE LOWERCASE_ENV GIT_BIN
export ROOT_PROJECT_DIR PROJECT_SETUP PROJECT_NAME DEFAULT_PROJECT_NAME
export LANGUAGE_TYPE SOURCE_ARTIFACT_TYPE_NAME BINARY_ARTIFACT_TYPE_NAME
export OUTPUT_FOLDER TEST_REPORTS_FOLDER
SOURCE_ARTIFACT_TYPE_NAME="source"
BINARY_ARTIFACT_TYPE_NAME="binary"

# ================================================================
#            DEFAULTS FOR PAAS, ENVIRONMENT, LANGUAGE
# ================================================================
PAAS_TYPE="$( toLowerCase "${PAAS_TYPE:-cf}" )"
# Not every linux distribution comes with installation of JQ that is new enough
# to have the asci_downcase method. That's why we're using the global env variable
# At some point we'll deprecate this and use what JQ provides
LOWERCASE_ENV="$(toLowerCase "${ENVIRONMENT}")"
PIPELINE_DESCRIPTOR="${PIPELINE_DESCRIPTOR:-sc-pipelines.yml}"
GIT_BIN="${GIT_BIN:-git}"
DEFAULT_PROJECT_NAME="$(basename "$(pwd)")"
echo "Picked PAAS is [${PAAS_TYPE}]"
echo "Current environment is [${ENVIRONMENT}]"
echo "Project name [${PROJECT_NAME}]"
parsePipelineDescriptor
defineProjectSetup

# ================================================================
#  [SOURCE] Sourcing a file that can pick proper build framework / language
# ================================================================
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
[[ -f "${__DIR}/projectType/pipeline-projectType.sh" ]] && source "${__DIR}/projectType/pipeline-projectType.sh" ||  \
 echo "No projectType/pipeline-projectType.sh found"

# ================================================================
#  With picked language type we can retrieve the project name
# ================================================================
# The result of sourcing project type will be the language type
LANGUAGE_TYPE="$(toLowerCase "${LANGUAGE_TYPE}")"
# Project name can be taken from env variable or from the project's app name
# We need it to tag the project somehow if the PROJECT_NAME var wasn't passed
if [[ "${PROJECT_NAME}" == "" || "${PROJECT_NAME}" == "null" ]]; then
	PROJECT_NAME="$(retrieveAppName)"
fi
echo "Project with name [${PROJECT_NAME}] is setup as [${PROJECT_SETUP}]. The project directory is present at [${ROOT_PROJECT_DIR}]"

# ================================================================
#  [SOURCE] Sourcing a file depending on the platform type
# ================================================================
# shellcheck source=/dev/null
[[ -f "${__ROOT}/pipeline-${PAAS_TYPE}.sh" ]] && source "${__ROOT}/pipeline-${PAAS_TYPE}.sh" ||  \
 echo "No pipeline-${PAAS_TYPE}.sh found"

# ================================================================
#  Customizing via the folder "custom/script_name.sh"
# ================================================================
export CUSTOM_SCRIPT_IDENTIFIER="${CUSTOM_SCRIPT_IDENTIFIER:-custom}"
echo "Custom script identifier is [${CUSTOM_SCRIPT_IDENTIFIER}]"
CUSTOM_SCRIPT_DIR="${__ROOT}/${CUSTOM_SCRIPT_IDENTIFIER}"
mkdir -p "${__ROOT}/${CUSTOM_SCRIPT_IDENTIFIER}"
CUSTOM_SCRIPT_NAME="$(basename "${BASH_SOURCE[1]}")"
echo "Path to custom script is [${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}]"

# ================================================================
#  [SOURCE] Sourcing a custom script if one is available
# ================================================================
# shellcheck source=/dev/null
[[ -f "${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}" ]] && source "${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME}" ||  \
 echo "No ${CUSTOM_SCRIPT_DIR}/${CUSTOM_SCRIPT_NAME} found"

OUTPUT_FOLDER="$(outputFolder)"
TEST_REPORTS_FOLDER="$(testResultsAntPattern)"

echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

# ================================================================
#           DEFINING PROJECT SETUP / LANGUAGE - END
# ================================================================

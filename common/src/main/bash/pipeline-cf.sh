#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Contains all Cloud Foundry related deployment functions
# }}}

# FUNCTION: logInToPaas {{{
# Implementation of the CF log in. Will work in the following way:
#
# * Will use CF if one is present (good for envs that are fully offline)
# * You can disable the redownload CF with [CF_REDOWNLOAD_CLI] env set to [false]
# * You can provide the URL from which to fetch the CLI via [CF_CLI_URL]
#
# Also [CF_TEST_MODE] is used for tests and all the combinations of
# [PAAS_..._USERNAME/PASSWORD/ORG/SPACE/API_URL] to log in to PAAS
function logInToPaas() {
	local user="PAAS_${ENVIRONMENT}_USERNAME"
	local cfUsername="${!user}"
	local pass="PAAS_${ENVIRONMENT}_PASSWORD"
	local cfPassword="${!pass}"
	local org="PAAS_${ENVIRONMENT}_ORG"
	local cfSpace
	local cfOrg="${!org}"
	if [[ "${LOWERCASE_ENV}" == "test" ]]; then
		local appName
		appName=$(retrieveAppName)
		cfSpace="${PAAS_TEST_SPACE_PREFIX}-${appName}"
	else
		local space="PAAS_${ENVIRONMENT}_SPACE"
		cfSpace="${!space}"
	fi
	local api="PAAS_${ENVIRONMENT}_API_URL"
	local apiUrl="${!api:-api.run.pivotal.io}"
	local cfToDownload="${CF_REDOWNLOAD_CLI:-true}"
	local cfPresent
	cfPresent="$( "${CF_BIN}" --version && echo "true" || echo "false" )"

	echo "CF CLI present? [${cfPresent}] and force to redownload was set? [${cfToDownload}]"

	if [[ "${cfToDownload}" != "false" || "${cfPresent}" == "false" ]]; then
		echo "Downloading Cloud Foundry CLI"
		curl -L "${CF_CLI_URL}" --fail | tar -zx
		# used by tests
		if [[ "${CF_TEST_MODE}" != "true" ]]; then
			CF_BIN="$(pwd)/cf"
			chmod +x "${CF_BIN}"
		fi
	fi

	echo "Cloud Foundry CLI version"
	"${CF_BIN}" --version

	echo "Logging in to CF to org [${cfOrg}], space [${cfSpace}]"
	"${CF_BIN}" api --skip-ssl-validation "${apiUrl}"
	"${CF_BIN}" login -u "${cfUsername}" -p "${cfPassword}" -o "${cfOrg}" -s "${cfSpace}"
} # }}}

# FUNCTION: testCleanup {{{
# Uses a community plugin to clean up the whole test space
function testCleanup() {
	# TODO: Clean up space without relying on plug-ins???
	#TODO: offline mode for when there is no internet connection
	"${CF_BIN}" install-plugin do-all -r "CF-Community" -f
	"${CF_BIN}" do-all delete {} -r -f
} # }}}

# FUNCTION: deleteService {{{
# Implementation of the CF delete service
#
# $1 - service name
# $2 - service type
function deleteService() {
	local serviceName
	serviceName=$(toLowerCase "${1}")
	local serviceType="${2}"
	"${CF_BIN}" delete -f "${serviceName}" || echo "Failed to delete app [${serviceName}]"
	"${CF_BIN}" delete-service -f "${serviceName}" || echo "Failed to delete service [${serviceName}]"
} # }}}

# FUNCTION: testDeploy {{{
# Implementation of the CF deployment to test
function testDeploy() {
	# TODO: Consider making it less JVM specific
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)

	logInToPaas
	testCleanup

	deployServices
	waitForServicesToInitialize

	# deploy app
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"
	deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}"
	propagatePropertiesForTests "${appName}"
} # }}}

# FUNCTION: testRollbackDeploy {{{
# Implementation of the CF deployment to test for rollback tests
function testRollbackDeploy() {
	rm -rf "${OUTPUT_FOLDER}/test.properties"
	local latestProdTag="${1}"
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)
	# shellcheck disable=SC2119
	parsePipelineDescriptor
	# Downloading latest jar
	local LATEST_PROD_VERSION=${latestProdTag#"prod/${PROJECT_NAME}/"}
	echo "Last prod version equals ${LATEST_PROD_VERSION}"
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${LATEST_PROD_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
	logInToPaas
	deleteApp "${appName}"
	deployAndRestartAppWithName "${appName}" "${appName}-${LATEST_PROD_VERSION}"
	propagatePropertiesForTests "${appName}"
	# Adding latest prod tag
	echo "LATEST_PROD_TAG=${latestProdTag}" >>"${OUTPUT_FOLDER}/test.properties"
} # }}}

# FUNCTION: deployService {{{
# Implementation of the CF deployment of a service
#
# $1 - service name
# $2 - service type
function deployService() {
	local serviceName="${1}"
	local serviceType="${2}"

	case ${serviceType} in
		broker)
			local broker
			broker="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .broker')"
			local plan
			plan="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .plan')"
			local params
			params="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .params')"
			deployBrokeredService "${serviceName}" "${broker}" "${plan}" "${params}"
		;;
		app)
			local pathToManifest
			pathToManifest="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .pathToManifest')"
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates')"
			local coordinatesSeparator=":"
			local PREVIOUS_IFS="${IFS}"
			IFS=${coordinatesSeparator} read -r APP_GROUP_ID APP_ARTIFACT_ID APP_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			downloadAppBinary "${REPO_WITH_BINARIES}" "${APP_GROUP_ID}" "${APP_ARTIFACT_ID}" "${APP_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
			deployAppAsService "${APP_ARTIFACT_ID}-${APP_VERSION}" "${serviceName}" "${pathToManifest}"
		;;
		cups)
			# Usage: cf cups SERVICE_INSTANCE -p CREDENTIALS (or credentials file)
			local params
			params="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .params')"
			deployCupsService "${serviceName}" "-p" "${params}"
		;;
		cupsSyslog)
			# Usage: cf cups SERVICE_INSTANCE -l SYSLOG_DRAIN_URL
			local syslogDrainUrl
			syslogDrainUrl="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .url')"
			deployCupsService "${serviceName}" "-l" "${syslogDrainUrl}"
		;;
		cupsRoute)
			# Usage: cf cups SERVICE_INSTANCE -r ROUTE_SERVICE_URL
			local routeServiceurl
			routeServiceurl="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .url')"
			deployCupsService "${serviceName}" "-r" "${routeServiceurl}"
		;;
		stubrunner)
			local pathToManifest
			pathToManifest="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .pathToManifest')"
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates')"
			local coordinatesSeparator=":"
			local PREVIOUS_IFS="${IFS}"
			IFS="${coordinatesSeparator}" read -r STUBRUNNER_GROUP_ID STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			downloadAppBinary "${REPO_WITH_BINARIES}" "${STUBRUNNER_GROUP_ID}" "${STUBRUNNER_ARTIFACT_ID}" "${STUBRUNNER_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
			deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${serviceName}" "${pathToManifest}"
		;;
		*)
			echo "Unknown service type [${serviceType}] for service name [${serviceName}]"
			return 1
		;;
	esac
} # }}}

# FUNCTION: deployAndRestartAppWithName {{{
# Deploys and restarts app with name $1 and binary name $2
#
# $1 - app name
# $2 - binary name
function deployAndRestartAppWithName() {
	local appName="${1}"
	local binaryName="${2}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local profiles
	if [[ "${ENVIRONMENT}" == "TEST" ]]; then
		profiles="cloud,smoke,test"
	elif [[ "${ENVIRONMENT}" == "STAGE" ]]; then
		profiles="cloud,e2e,stage"
	elif [[ "${ENVIRONMENT}" == "PROD" ]]; then
		profiles="cloud,prod"
	fi
	parseManifest
	local manifestProfiles
	manifestProfiles="$(getProfilesFromManifest "${appName}")"
	if [[ ! -z "${manifestProfiles}" && "${manifestProfiles}" != "null" ]]; then
		profiles="${profiles},${manifestProfiles}"
	fi
	echo "Deploying and restarting app with name [${appName}] and binary name [${binaryName}] and env [${ENVIRONMENT}]"
	deployAppNoStart "${appName}" "${binaryName}" "${ENVIRONMENT}" "" ""
	setEnvVar "${lowerCaseAppName}" 'SPRING_PROFILES_ACTIVE' "${profiles}"
	restartApp "${appName}"
} # }}}

# FUNCTION: parseManifest {{{
# Parses the [manifest.yml] file into [PARSED_APP_MANIFEST_YAML] env var
function parseManifest() {
	if [ -z "${PARSED_APP_MANIFEST_YAML}" ]; then
		if [[ ! -f "manifest.yml" ]]; then
			echo "App manifest.yml file not found"
			return 1
		fi
		export PARSED_APP_MANIFEST_YAML
		PARSED_APP_MANIFEST_YAML="$(yaml2json "manifest.yml")"
	fi
} # }}}

# FUNCTION: getProfilesFromManifest {{{
# Gets profiles from [PARSED_APP_MANIFEST_YAML] for app with name $1
#
# $1 - app name
function getProfilesFromManifest() {
	local appName="${1}"
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq -r --arg x "${appName}" '.applications[] | select(.name = $x) | .env | .SPRING_PROFILES_ACTIVE'
} # }}}

# FUNCTION: getHostFromManifest {{{
# Gets host from [PARSED_APP_MANIFEST_YAML] for app with name $1
#
# $1 - app name
function getHostFromManifest() {
	local appName="${1}"
	local host
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq -r --arg x "${appName}" '.applications[] | select(.name = $x) | .host'
} # }}}

# FUNCTION: getInstancesFromManifest {{{
# Gets instances from [PARSED_APP_MANIFEST_YAML] for app with name $1
#
# $1 - app name
function getInstancesFromManifest() {
	local appName="${1}"
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq -r --arg x "${appName}" '.applications[] | select(.name = $x) | .instances'
} # }}}

# FUNCTION: getAppHostFromPaas {{{
# Gets app host for app with name $1 from CF
#
# $1 - app name
function getAppHostFromPaas() {
	local appName="${1}"
	local lowerCase
	lowerCase="$(toLowerCase "${appName}")"
	"${CF_BIN}" apps | awk -v "app=${lowerCase}" '$1 == app {print($0)}' | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1 | head -1
} # }}}

# FUNCTION: getDomain {{{
# Gets domain from host $1
#
# $1 - host name
function getDomain() {
	local hostName="${1}"
	${CF_BIN} routes | grep "${hostName}" | head -1 | awk '{print $3}'
} # }}}

# FUNCTION: deployAppNoStart {{{
# Deploys an app without starting it
#
# $1 - app name
# $2 - artifact name
# $3 - environment name
# $4 - path to manifest
# $5 - host name suffix
function deployAppNoStart() {
	local appName="${1}"
	local artifactName="${2}"
	local env="${3}"
	local pathToManifest="${4}"
	local hostNameSuffix="${5}"
	# we need to change directory to source if necessary
	local artifactType
	artifactType="$( getArtifactType )"
	echo "Project has artifact type [${artifactType}]"
	if [[ "${artifactType}" == "${SOURCE_ARTIFACT_TYPE_NAME}" && "${DOWNLOADABLE_SOURCES}" == "true" ]]; then
		local dir
		dir="$(pathToUnpackedSources)"
		mkdir -p "${dir}"
		pushd "${dir}"
	fi
	if [[ -z "${pathToManifest}" || "${pathToManifest}" == "null" ]]; then
		pathToManifest="manifest.yml"
	fi
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local hostname
	hostname="$(hostname "${appName}" "${env}" "${pathToManifest}")"
	if [[ "${hostNameSuffix}" != "" ]]; then
		hostname="${hostname}-${hostNameSuffix}"
	fi
	# TODO set "i 1" for test only, leave manifest value for stage and prod
	local instances
	instances="$(getInstancesFromManifest "${appName}")"
	if [[ ${env} == "TEST" || -z "${instances}" || "${instances}" == "null" ]]; then
		instances=1
	fi
	local pathToPush
	pathToPush="$( pathToPushToCf "${artifactName}" )"
	echo "Deploying app with name [${lowerCaseAppName}], env [${env}] and host [${hostname}] with manifest file [${pathToManifest}] and path to push [${pathToPush}]. The sources should be downloadable [${DOWNLOADABLE_SOURCES}]"
	"${CF_BIN}" push "${lowerCaseAppName}" -f "${pathToManifest}" -p "${pathToPush}" -n "${hostname}" -i "${instances}" --no-start
	setEnvVar "${lowerCaseAppName}" 'APP_BINARY' "${artifactName}.${BINARY_EXTENSION}"
	if [[ "${artifactType}" == "${SOURCE_ARTIFACT_TYPE_NAME}" && "${DOWNLOADABLE_SOURCES}" == "true" ]]; then
		popd
	fi
} # }}}

# FUNCTION: getArtifactType {{{
# Gets the type of artifact that should be pushed to CF. [binary] or [source]?
# Uses [ARTIFACT_TYPE], [PARSED_YAML], [LANGUAGE_TYPE] env vars
function getArtifactType() {
	if [[ "${ARTIFACT_TYPE}" != "" ]]; then
		echo "${ARTIFACT_TYPE}"
	elif [[ ! -z "${PARSED_YAML}" ]]; then
		local artifactType
		artifactType="$( echo "${PARSED_YAML}" | jq -r '.artifact_type' )"
		if [[ "${artifactType}" == "null" ]]; then
			if [[ "${LANGUAGE_TYPE}" == "php" ]]; then
				artifactType="${SOURCE_ARTIFACT_TYPE_NAME}"
			else
				artifactType="${BINARY_ARTIFACT_TYPE_NAME}"
			fi
		fi
		toLowerCase "${artifactType}"
	else
		echo "${BINARY_ARTIFACT_TYPE_NAME}"
	fi
} # }}}

# FUNCTION: pathToPushToCf {{{
# Returns the path to push to CF for artifact with name $1
#
# $1 - artifact name
function pathToPushToCf() {
	local artifactName="${1}"
	local artifactType
	artifactType="$( getArtifactType )"
	if [[ "${artifactType}" == "${BINARY_ARTIFACT_TYPE_NAME}" ]]; then
		echo "${OUTPUT_FOLDER}/${artifactName}.${BINARY_EXTENSION}"
	elif [[ "${artifactType}" == "${SOURCE_ARTIFACT_TYPE_NAME}" ]]; then
		echo "."
	else
		echo "Unknown artifact type"
		return 1
	fi
} # }}}

# FUNCTION: pathToUnpackedSources {{{
# Returns the path to unpacked sources. Uses [OUTPUT_FOLDER] env var
function pathToUnpackedSources() {
	echo "${OUTPUT_FOLDER}/source"
} # }}}

# FUNCTION: hostname {{{
# Returns hostname for app with name $1, env $2 and manifest location $3
# Uses [PAAS_HOSTNAME_UUID] and [LOWERCASE_ENV] env vars
#
# $1 - app name
# $2 - environment name
# $3 - manifest location
function hostname() {
	local appName="${1}"
	local env="${2}"
	local pathToManifest="${3}"
	if [[ -z "${pathToManifest}" || "${pathToManifest}" == "null" ]]; then
		pathToManifest="manifest.yml"
	fi
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local hostname
	hostname="$(getHostFromManifest "${appName}")"
	if [[ -z "${hostname}" || "${hostname}" == "null" ]]; then
		hostname="${lowerCaseAppName}"
	fi
	# Even if host is specified in the manifest, append the hostname uuid from the credentials file
	# TODO Reconsider - now that we are using the manifest, don't need this... also what if random-route is true?
	if [[ "${PAAS_HOSTNAME_UUID}" != "" && "${PAAS_HOSTNAME_UUID}" != "null" ]]; then
		hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
	fi
	if [[ ${env} != "PROD" ]]; then
		hostname="${hostname}-${LOWERCASE_ENV}"
	fi
	echo "${hostname}"
} # }}}

# FUNCTION: deleteApp {{{
# Deletes app with name $1 from CF
#
# $1 - app name
function deleteApp() {
	local appName="${1}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local APP_NAME="${lowerCaseAppName}"
	echo "Deleting application [${APP_NAME}]"
	# Delete app and route
	"${CF_BIN}" delete -f -r "${APP_NAME}" || echo "Failed to delete the app. Continuing with the script"
} # }}}

# FUNCTION: setEnvVarIfMissing {{{
# For app with name $1 sets env var with key $2 and value $3 if that value is missing
#
# $1 - app name
# $2 - env variable key
# $3 - env variable value
function setEnvVarIfMissing() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}] if missing"
	"${CF_BIN}" env "${appName}" | grep "${key}" || setEnvVar appName key value
} # }}}

# FUNCTION: setEnvVar {{{
# For app with name $1 sets env var with key $2 and value $3
#
# $1 - app name
# $2 - env variable key
# $3 - env variable value
function setEnvVar() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}]"
	"${CF_BIN}" set-env "${appName}" "${key}" "${value}"
} # }}}

# FUNCTION: restartApp {{{
# Restarts app with name $1
#
# $1 - app name
function restartApp() {
	local appName="${1}"
	echo "Restarting app with name [${appName}]"
	"${CF_BIN}" restart "${appName}"
} # }}}

# FUNCTION: deployAppAsService {{{
# For app with binary name $1, app name $2 and manifest location $3, deploys the app to CF
# and creates a user provided services for it
#
# $1 - binary name
# $2 - app name
# $3 - manifest location
function deployAppAsService() {
	local binaryName="${1}"
	local appName="${2}"
	local pathToManifest="${3}"
	echo "Deploying app as service. Options - binary name [${binaryName}], app name [${appName}], env [${ENVIRONMENT}], path to manifest [${pathToManifest}]"
	local suffix=""
	if [[ "${LOWERCASE_ENV}" == "test" ]]; then
		suffix="$(retrieveAppName)"
	fi
	deployAppNoStart "${appName}" "${binaryName}" "${ENVIRONMENT}" "${pathToManifest}" "${suffix}"
	restartApp "${appName}"
	createServiceWithName "${appName}"
} # }}}

# FUNCTION: deployBrokeredService {{{
# Deploys a brokered service with name $1, broker service type $2, plan $3 and parameters $4
#
# $1 - service name
# $2 - broker service type
# $3 - broker service plan
# $4 - broker service parameters
function deployBrokeredService() {
	local serviceName="${1}"
	local broker="${2}"
	local plan="${3}"
	local params="${4}"
	if [[ -z "${params}" || "${params}" == "null" ]]; then
		"${CF_BIN}" create-service "${broker}" "${plan}" "${serviceName}" || echo "Service failed to be created. Most likely that's because it's already created. Continuing with the script"
		echo "Deploying [${serviceName}] via Service Broker in [${LOWERCASE_ENV}] env. Options - broker [${broker}], plan [${plan}]"
	else
		echo "Deploying [${serviceName}] via Service Broker in [${LOWERCASE_ENV}] env. Options - broker [${broker}], plan [${plan}], params:"
		echo "${params}"
		# Write params to file:
		local destination
		destination="$(pwd)/${OUTPUT_FOLDER}/${serviceName}-service-params.json"
		mkdir -p "${OUTPUT_FOLDER}"
		echo "Writing params to [${destination}]"
		echo "${params}" > "${destination}"
		"${CF_BIN}" create-service "${broker}" "${plan}" "${serviceName}" -c "${destination}"  || echo "Service failed to be created. Most likely that's because it's already created. Continuing with the script"

#		   TODO: For create-service, there is a -t tags parameter -  add support for this?
#		   TODO: For create-service and cups, do we need to consider updates for services that already exist?
		# TODO: Marcin discussion - decision: hanlde the update using a diff in test-rollback
	fi
} # }}}

# FUNCTION: deployCupsService {{{
# Deploys a CUPS (user provided service) with name $1, option $2 and value $3
# Uses [OUTPUT_FOLDER] and [LOWERCASE_ENV] env variables
#
# $1 - service name
# $2 - cups option
# $3 - cups value
function deployCupsService() {
	# cupsOption should be -l, -r, or -p
	local serviceName="${1}"
	local cupsOption="${2}"
	local cupsValue="${3}"
	# This means credentials are in sc-pipeline.yml, but only for test and potentially stage, not prod
	echo "Deploying [${serviceName}] via cups in [${LOWERCASE_ENV}] env. Options - [${cupsOption} ${cupsValue}]"
	# TODO: reevaluate if a file is necessary
	if [[ "${cupsOption}" == "-p" ]]; then
		# Write params to file:
		local destination
		destination="$(pwd)/${OUTPUT_FOLDER}/${serviceName}-service-params.json"
		mkdir -p "${OUTPUT_FOLDER}"
		echo "Writing params to [${destination}]"
		echo "${cupsValue}" > "${destination}"
		cupsValue="${destination}"
	fi
	"${CF_BIN}" cups "${serviceName}" "${cupsOption}" "${cupsValue}" || echo "Service already created. Proceeding with the script"
} # }}}

# FUNCTION: createServiceWithName {{{
# Creates a CUPS (user provided service) for service with name $1
#
# $1 - service name
function createServiceWithName() {
	local name="${1}"
	echo "Creating service with name [${name}]"
	APPLICATION_DOMAIN="$(getAppHostFromPaas "${name}")"
	JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
	deployCupsService "${name}" "-p" "${JSON}"
} # }}}

# used for tests
export RETRIEVE_STUBRUNNER_IDS_FUNCTION="${RETRIEVE_STUBRUNNER_IDS_FUNCTION:-retrieveStubRunnerIds}"

# FUNCTION: deployStubRunnerBoot {{{
# Deploys a Stub Runner Boot instance to CF
# Uses [REPO_WITH_BINARIES], [ENVIRONMENT] env vars
#
# $1 - Stub Runner Boot jar name
# $2 - Stub Runner name
# $3 - path to Stub Runner manifest
function deployStubRunnerBoot() {
	local jarName="${1}"
	local stubRunnerName="${2}"
	local pathToManifest="${3}"
	local suffix
	suffix="$(retrieveAppName)"
	echo "Deploying Stub Runner. Options binary name [${jarName}], app name [${stubRunnerName}], manifest [${pathToManifest}], suffix [${suffix}]"
	deployAppNoStart "${stubRunnerName}" "${jarName}" "${ENVIRONMENT}" "${pathToManifest}" "${suffix}"
	local prop
	prop="$(${RETRIEVE_STUBRUNNER_IDS_FUNCTION})"
	echo "Found following stub runner ids [${prop}]"
	if [[ "${prop}" != "" ]]; then
		addMultiplePortsSupport "${stubRunnerName}" "${prop}" "${pathToManifest}"
		setEnvVar "${stubRunnerName}" "stubrunner.ids" "${prop}"
	fi
	setEnvVar "${stubRunnerName}" "REPO_WITH_BINARIES" "${REPO_WITH_BINARIES}"
	restartApp "${stubRunnerName}"
} # }}}

# FUNCTION: addMultiplePortsSupport {{{
# Adds multiple ports support for Stub Runner Boot
# Uses [PAAS_TEST_SPACE_PREFIX], [ENVIRONMENT] env vars
#
# $1 - Stub Runner name
# $2 - IDs of stubs to be downloaded
# $3 - path to Stub Runner manifest
function addMultiplePortsSupport() {
	local stubRunnerName="${1}"
	local stubrunnerIds="${2}"
	local pathToManifest="${3}"
	local appName
	appName=$(retrieveAppName)
	local hostname
	hostname="$(hostname "${stubRunnerName}" "${ENVIRONMENT}" "${pathToManifest}")"
	hostname="${hostname}-${appName}"
	echo "Hostname for ${stubRunnerName} is ${hostname}"
	local testSpace="${PAAS_TEST_SPACE_PREFIX}-${appName}"
	local domain
	domain="$( getDomain "${hostname}" )"
	echo "Domain for ${stubRunnerName} is ${domain}"
	# APPLICATION_HOSTNAME and APPLICATION_DOMAIN will be used for stub registration. Stub Runner Boot
	# will use this environment variable to hardcode the hostname of the stubs
	setEnvVar "${stubRunnerName}" "APPLICATION_HOSTNAME" "${hostname}"
	setEnvVar "${stubRunnerName}" "APPLICATION_DOMAIN" "${domain}"
	local previousIfs="${IFS}"
	local listOfPorts=""
	local appGuid
	appGuid="$( "${CF_BIN}" curl "/v2/apps?q=name:${stubRunnerName}" -X GET | jq -r '.resources[0].metadata.guid' )"
	echo "App GUID for ${stubRunnerName} is ${appGuid}"
	IFS="," read -ra vals <<< "${stubrunnerIds}"
	for stub in "${vals[@]}"; do
		echo "Parsing ${stub}"
		local port
		port=${stub##*:}
		if [[ "${listOfPorts}" == "" ]]; then
			listOfPorts="${port}"
		else
			listOfPorts="${listOfPorts},${port}"
		fi
	done
	echo "List of added ports: [${listOfPorts}]"
	"${CF_BIN}" curl "/v2/apps/${appGuid}" -X PUT -d "{\"ports\":[8080,${listOfPorts}]}"
	echo "Successfully updated the list of ports for [${stubRunnerName}]"
	IFS="," read -ra vals <<< "${stubrunnerIds}"
	for stub in "${vals[@]}"; do
		echo "Parsing ${stub}"
		local port
		port=${stub##*:}
		local newHostname="${hostname}-${port}"
		echo "Creating route with hostname [${newHostname}]"
		"${CF_BIN}" create-route "${testSpace}" "${domain}" --hostname "${newHostname}"
		local routeGuid
		routeGuid="$( "${CF_BIN}" curl -X GET "/v2/routes?q=host:${newHostname}" | jq -r '.resources[0].metadata.guid' )"
		echo "GUID of the new route is [${routeGuid}]. Will update the mapping for port [${port}]"
		"${CF_BIN}" curl "/v2/route_mappings" -X POST -d "{ \"app_guid\": \"${appGuid}\", \"route_guid\": \"${routeGuid}\", \"app_port\": ${port} }"
		echo "Successfully updated the new route mapping for port [${port}]"
	done
	IFS="${previousIfs}"
} # }}}

# FUNCTION: bindService {{{
# Binds service $1 to application $2
#
# $1 - service name
# $2 - application name
function bindService() {
	local serviceName="${1}"
	local appName="${2}"
	local serviceExists="no"
	echo "Checking if service with name [${serviceName}] exists"
	"${CF_BIN}" service "${serviceName}" && serviceExists="yes" || echo "Service is not there"
	if [[ "${serviceExists}" == "yes" ]]; then
		echo "Binding service [${serviceName}] to app [${appName}]"
		"${CF_BIN}" bind-service "${appName}" "${serviceName}"
	fi
} # }}}

# FUNCTION: prepareForSmokeTests {{{
# CF implementation of prepare for smoke tests, can log in to PAAS to retrieve info about
# the app. You can skip that via [CF_SKIP_PREPARE_FOR_TESTS] set to [true]
function prepareForSmokeTests() {
	if [[ "${CF_SKIP_PREPARE_FOR_TESTS}" == "true" ]]; then
		echo "Skipping host retrieval, continuing with tests"
		return 0
	fi
	echo "Retrieving group and artifact id - it can take a while..."
	local appName
	appName="$(retrieveAppName)"
	mkdir -p "${OUTPUT_FOLDER}"
	logInToPaas
	parsePipelineDescriptor
	propagatePropertiesForTests "${appName}"
	# shellcheck disable=SC2119
	readTestPropertiesFromFile
	echo "Application URL [${APPLICATION_URL}]"
	echo "StubRunner URL [${STUBRUNNER_URL}]"
	echo "Latest production tag [${LATEST_PROD_TAG}]"
} # }}}

# FUNCTION: prepareForE2eTests {{{
# CF implementation of prepare for e2e tests
# You can skip that via [CF_SKIP_PREPARE_FOR_TESTS] set to [true]
function prepareForE2eTests() {
	if [[ "${CF_SKIP_PREPARE_FOR_TESTS}" == "true" ]]; then
		echo "Skipping host retrieval, continuing with tests"
		return 0
	fi
	logInToPaas

	export APPLICATION_URL
	APPLICATION_URL="$(retrieveApplicationUrl | tail -1)"
	echo "Application URL [${APPLICATION_URL}]"
} # }}}

# FUNCTION: readTestPropertiesFromFile {{{
# Reads a properties file as env variables
# shellcheck disable=SC2120
function readTestPropertiesFromFile() {
	local fileLocation="${1:-${OUTPUT_FOLDER}/test.properties}"
	if [ -f "${fileLocation}" ]
	then
		echo "${fileLocation} found."
		while IFS='=' read -r key value
		do
			key=$(echo "${key}" | tr '.' '_')
			eval "${key}='${value}'"
		done <"${fileLocation}"
	else
		echo "${fileLocation} not found."
	fi
} # }}}

# FUNCTION: stageDeploy {{{
# CF implementation of deployment to stage
function stageDeploy() {
	# TODO: Consider making it less JVM specific
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)
	# Log in to PaaS to start deployment
	logInToPaas

	deployServices
	waitForServicesToInitialize

	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"

	# deploy app
	deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}"
	propagatePropertiesForTests "${appName}"
} # }}}

# FUNCTION: retrieveApplicationUrl {{{
# Retrieves the application URL from CF
function retrieveApplicationUrl() {
	echo "Retrieving artifact id - it can take a while..."
	local appName
	appName="$(retrieveAppName)"
	echo "Project artifactId is ${appName}"
	mkdir -p "${OUTPUT_FOLDER}"
	logInToPaas
	propagatePropertiesForTests "${appName}"
	# shellcheck disable=SC2119
	readTestPropertiesFromFile
	echo "${APPLICATION_URL}"
} # }}}

# FUNCTION: prodDeploy {{{
# CF implementation of deploy to production
function prodDeploy() {
	local projectGroupId
	projectGroupId="$(retrieveGroupId)"
	local appName
	appName="$(retrieveAppName)"

	# download app
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
	# Log in to CF to start deployment
	logInToPaas

	# deploy app
	performProductionDeploymentOfTestedApplication "${appName}"
} # }}}

# FUNCTION: performProductionDeploymentOfTestedApplication {{{
# Performs production deployment of application (APP)
# APP - current app to deploy, VEN - old (venerable), currently running app on production
# [Clicked DEPLOY] -> APP running, VEN running -> [Click DEPLOY] delete VEN, deploy new APP
# [Clicked COMPLETE] -> APP running, VEN stopped -> [Click DEPLOY] delete VEN, rename APP -> VEN, deploy APP
# [Clicked ROLLBACK] -> APP stopped, VEN running, VEN renamed to APP, latest PROD tag removed -> [Click DEPLOY] -> delete APP, deploy new APP, stop VEN
function performProductionDeploymentOfTestedApplication() {
	local appName="${1}"
	local newName="${appName}-venerable"
	echo "Renaming the app from [${appName}] -> [${newName}]"
	local appPresent="no"
	local appRunning="no"
	local venerableAppPresent="no"
	local venerableAppRunning="no"
	local noRunningAppsMsg="There are no running instances"
	"${CF_BIN}" app "${appName}" | grep -v "${noRunningAppsMsg}" && appRunning="yes"
	"${CF_BIN}" app "${newName}" && venerableAppPresent="yes"
	"${CF_BIN}" app "${newName}" | grep -v "${noRunningAppsMsg}" && venerableAppRunning="yes"
	if [[ "${appRunning}" == "yes" ]]; then
		if [[ "${venerableAppPresent}" == "yes" ]]; then
			echo "Old instance is present, will remove it"
			"${CF_BIN}" delete "${newName}" -f
		fi
		"${CF_BIN}" rename "${appName}" "${newName}"
	elif [[ "${appRunning}" == "no"  && "${venerableAppRunning}" == "yes" ]]; then
		echo "Deploying new application after rolling back"
		echo "Removing new instance"
		"${CF_BIN}" delete "${appName}" -f
		echo "Renaming old instance to new"
		"${CF_BIN}" rename "${newName}" "${appName}"
	else
		echo "Will not rename the application cause it's not there and old is not running"
	fi
	deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}"
} # }}}

# FUNCTION: rollbackToPreviousVersion {{{
# Performs rollback of application (APP)
# APP - current app to deploy, VEN - old (venerable), currently running app on production
# [Clicked ROLLBACK] -> APP stopped, VEN running
function rollbackToPreviousVersion() {
	local appName
	appName="$(retrieveAppName)"
	# Log in to CF to start deployment
	logInToPaas
	local oldName="${appName}-venerable"
	echo "Rolling back to [${oldName}]"
	local appPresent="no"
	"${CF_BIN}" app "${oldName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		echo "Starting blue (if it wasn't started) and stopping the green instance. Only blue instance will be running"
		"${CF_BIN}" start "${oldName}"
		"${CF_BIN}" delete "${appName}" -f
		return 0
	else
		echo "Will not rollback to blue instance cause it's not there"
		return 1
	fi
} # }}}

# FUNCTION: completeSwitchOver {{{
# Performs switch over of the venerable app (VEN) and leaves only current one (APP) running
# APP - current app to deploy, VEN - old (venerable), currently running app on production
# [Clicked COMPLETE] -> APP running, VEN stopped
function completeSwitchOver() {
	local appName
	appName="$(retrieveAppName)"
	# Log in to CF to start deployment
	logInToPaas
	local oldName="${appName}-venerable"
	echo "Deleting the app [${oldName}]"
	local appPresent="no"
	"${CF_BIN}" app "${oldName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		"${CF_BIN}" stop "${oldName}"
	else
		echo "Will not stop the old application cause it's not there"
	fi
} # }}}

# FUNCTION: propagatePropertiesForTests {{{
# For project with name $1 resolves application URL and stub runner URL if applicable
#
# exports [APPLICATION_URL] and [STUBRUNNER_URL] env vars and stores those values in a
# properties file
#
# $1 - application name
function propagatePropertiesForTests() {
	local projectArtifactId="${1}"
	local serviceType="stubrunner"
	local nodeExists
	envNodeExists "${LOWERCASE_ENV}" && nodeExists="true" || nodeExists="false"
	local stubRunnerName=""
	if [[ "${nodeExists}" == "true" ]]; then
		stubRunnerName="$(echo "${PARSED_YAML}" |  jq -r --arg x "${LOWERCASE_ENV}" --arg y "${serviceType}" '.[$x].services[] | select(.name == $y) | .name')"
	fi
	local fileLocation="${OUTPUT_FOLDER}/test.properties"
	echo "Propagating properties for tests. Project [${projectArtifactId}] stub runner app name [${stubRunnerName}] properties location [${fileLocation}]"
	# retrieve host of the app / stubrunner
	# we have to store them in a file that will be picked as properties
	rm -rf "${fileLocation}"
	mkdir -p "${OUTPUT_FOLDER}"
	local host
	host="$(getAppHostFromPaas "${projectArtifactId}")"
	export APPLICATION_URL="${host}"
	echo "APPLICATION_URL=${host}" >>"${fileLocation}"
	host=$(getAppHostFromPaas "${stubRunnerName}")
	export STUBRUNNER_URL="${host}"
	echo "STUBRUNNER_URL=${host}" >>"${fileLocation}"
	echo "Resolved properties"
	cat "${fileLocation}"
} # }}}

# FUNCTION: waitForServicesToInitialize {{{
# Waits for services to initialize
function waitForServicesToInitialize() {
	# Wait until services are ready
	while "${CF_BIN}" services | grep 'create in progress'
	do
		sleep 10
		echo "Waiting for services to initialize..."
	done

	# Check to see if any services failed to create
	if "${CF_BIN}" services | grep 'create failed'; then
		echo "Service initialization - failed. Exiting."
		return 1
	fi
	echo "Service initialization - successful"
} # }}}

export CF_BIN
CF_BIN="${CF_BIN:-cf}"
export CF_CLI_URL
CF_CLI_URL="${CF_CLI_URL:-https://cli.run.pivotal.io/stable?release=linux64-binary&source=github}"

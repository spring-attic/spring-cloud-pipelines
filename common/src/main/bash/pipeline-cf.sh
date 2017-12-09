#!/bin/bash

#set -e

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

	echo "Downloading Cloud Foundry CLI"
	#TODO: is there a way to get this from PCF rather than the latest release? Like fly... Would ensure parity with foundation version...
	#TODO: offline mode for when there is no internet connection
	curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" --fail | tar -zx
	chmod +x cf

	echo "Cloud Foundry CLI version"
	"${CF_BIN}" --version

	echo "Logging in to CF to org [${cfOrg}], space [${cfSpace}]"
	"${CF_BIN}" api --skip-ssl-validation "${apiUrl}"
	"${CF_BIN}" login -u "${cfUsername}" -p "${cfPassword}" -o "${cfOrg}" -s "${cfSpace}"
}

function testCleanup() {
	# TODO: Clean up space without relying on plug-ins???
	#TODO: offline mode for when there is no internet connection
	cf install-plugin do-all -r "CF-Community" -f
	cf do-all delete {} -r -f
}

function deleteService() {
	local serviceName
	serviceName=$(toLowerCase "${1}")
	local serviceType="${2}"
	"${CF_BIN}" delete -f "${serviceName}" || echo "Failed to delete app [${serviceName}]"
	"${CF_BIN}" delete-service -f "${serviceName}" || echo "Failed to delete service [${serviceName}]"
}

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
}

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
	local LATEST_PROD_VERSION=${latestProdTag#prod/}
	echo "Last prod version equals ${LATEST_PROD_VERSION}"
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${LATEST_PROD_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
	logInToPaas
	deleteApp "${appName}"
	deployAndRestartAppWithName "${appName}" "${appName}-${LATEST_PROD_VERSION}"
	propagatePropertiesForTests "${appName}"
	# Adding latest prod tag
	echo "LATEST_PROD_TAG=${latestProdTag}" >>"${OUTPUT_FOLDER}/test.properties"
}

function deployService() {
	local serviceName="${1}"
	local serviceType="${2}"

	case ${serviceType} in
		broker)
			local broker
			broker="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .broker' | sed 's/^"\(.*\)"$/\1/')"
			local plan
			plan="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .plan' | sed 's/^"\(.*\)"$/\1/')"
			local params
			params="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .params' | sed 's/^"\(.*\)"$/\1/')"
			deployBrokeredService "${serviceName}" "${broker}" "${plan}" "${params}"
		;;
		app)
			local pathToManifest
			pathToManifest="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .pathToManifest' | sed 's/^"\(.*\)"$/\1/')"
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates' | sed 's/^"\(.*\)"$/\1/')"
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
			params="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .params' | sed 's/^"\(.*\)"$/\1/')"
			deployCupsService "${serviceName}" "-p" "${params}"
		;;
		cupsSyslog)
			# Usage: cf cups SERVICE_INSTANCE -l SYSLOG_DRAIN_URL
			local syslogDrainUrl
			syslogDrainUrl="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .url' | sed 's/^"\(.*\)"$/\1/')"
			deployCupsService "${serviceName}" "-l" "${syslogDrainUrl}"
		;;
		cupsRoute)
			# Usage: cf cups SERVICE_INSTANCE -r ROUTE_SERVICE_URL
			local routeServiceurl
			routeServiceurl="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .url' | sed 's/^"\(.*\)"$/\1/')"
			deployCupsService "${serviceName}" "-r" "${routeServiceurl}"
		;;
		stubrunner)
			local pathToManifest
			pathToManifest="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .pathToManifest' | sed 's/^"\(.*\)"$/\1/')"
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates' | sed 's/^"\(.*\)"$/\1/')"
			local coordinatesSeparator=":"
			local PREVIOUS_IFS="${IFS}"
			IFS="${coordinatesSeparator}" read -r STUBRUNNER_GROUP_ID STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			downloadAppBinary "${REPO_WITH_BINARIES}" "${STUBRUNNER_GROUP_ID}" "${STUBRUNNER_ARTIFACT_ID}" "${STUBRUNNER_VERSION}" "${M2_SETTINGS_REPO_USERNAME}" "${M2_SETTINGS_REPO_PASSWORD}"
			deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${serviceName}"  "${pathToManifest}"
		;;
		*)
			echo "Unknown service type [${serviceType}] for service name [${serviceName}]"
			return 1
		;;
	esac
}

function deployAndRestartAppWithName() {
	local appName="${1}"
	local jarName="${2}"
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
	echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}] and env [${ENVIRONMENT}]"
	deployAppNoStart "${appName}" "${jarName}" "${ENVIRONMENT}" "" ""
	setEnvVar "${lowerCaseAppName}" 'SPRING_PROFILES_ACTIVE' "${profiles}"
	restartApp "${appName}"
}

function parseManifest() {
	if [ -z "${PARSED_APP_MANIFEST_YAML}" ]; then
		if [[ ! -f "manifest.yml" ]]; then
			echo "App manifest.yml file not found"
			return 1
		fi
		export PARSED_APP_MANIFEST_YAML
		PARSED_APP_MANIFEST_YAML="$(yaml2json "manifest.yml")"
	fi
}

function getProfilesFromManifest() {
	local appName="${1}"
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .env | .SPRING_PROFILES_ACTIVE' | sed 's/^"\(.*\)"$/\1/'
}

function getHostFromManifest() {
	local appName="${1}"
	local host
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .host' | sed 's/^"\(.*\)"$/\1/'
}

function getInstancesFromManifest() {
	local appName="${1}"
	echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .instances' | sed 's/^"\(.*\)"$/\1/'
}

function getAppHostFromPaas() {
	local appName="${1}"
	local lowerCase
	lowerCase="$(toLowerCase "${appName}")"
	"${CF_BIN}" apps | awk -v "app=${lowerCase}" '$1 == app {print($0)}' | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1 | head -1
}

function getDomain() {
	local hostName="${1}"
	${CF_BIN} routes | grep "${hostName}" | head -1 | awk '{print $3}'
}

function deployAppNoStart() {
	local appName="${1}"
	local artifactName="${2}"
	local env="${3}"
	local pathToManifest="${4}"
	local hostNameSuffix="${5}"
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
	echo "Deploying app with name [${lowerCaseAppName}], env [${env}] and host [${hostname}] with manifest file [${pathToManifest}]"
	"${CF_BIN}" push "${lowerCaseAppName}" -f "${pathToManifest}" -p "${OUTPUT_FOLDER}/${artifactName}.${BINARY_EXTENSION}" -n "${hostname}" -i "${instances}" --no-start
	setEnvVar "${lowerCaseAppName}" 'APP_BINARY' "${artifactName}.${BINARY_EXTENSION}"
}

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
	if [[ "${PAAS_HOSTNAME_UUID}" != "" ]]; then
		hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
	fi
	if [[ ${env} != "PROD" ]]; then
		hostname="${hostname}-${LOWERCASE_ENV}"
	fi
	echo "${hostname}"
}

function deleteApp() {
	local appName="${1}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local APP_NAME="${lowerCaseAppName}"
	echo "Deleting application [${APP_NAME}]"
	# Delete app and route
	"${CF_BIN}" delete -f -r "${APP_NAME}" || echo "Failed to delete the app. Continuing with the script"
}

function setEnvVarIfMissing() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}] if missing"
	"${CF_BIN}" env "${appName}" | grep "${key}" || setEnvVar appName key value
}

function setEnvVar() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}]"
	"${CF_BIN}" set-env "${appName}" "${key}" "${value}"
}

function restartApp() {
	local appName="${1}"
	echo "Restarting app with name [${appName}]"
	"${CF_BIN}" restart "${appName}"
}

function deployAppAsService() {
	local jarName="${1}"
	local appName="${2}"
	local pathToManifest="${3}"
	echo "Deploying app as service. Options - jar name [${jarName}], app name [${appName}], env [${ENVIRONMENT}], path to manifest [${pathToManifest}]"
	local suffix=""
	if [[ "${LOWERCASE_ENV}" == "test" ]]; then
		suffix="$(retrieveAppName)"
	fi
	deployAppNoStart "${appName}" "${jarName}" "${ENVIRONMENT}" "${pathToManifest}" "${suffix}"
	restartApp "${appName}"
	createServiceWithName "${appName}"
}

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
}

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
}

function createServiceWithName() {
	local name="${1}"
	echo "Creating service with name [${name}]"
	# TODO run edit by marcin - DO IT!
	#APPLICATION_DOMAIN="$("${CF_BIN}" apps | grep "${name}" | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1)"
	APPLICATION_DOMAIN="$(getAppHostFromPaas "${name}")"
	JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
	# TODO leverage method deployCupsService? Does || echo really help? Add it to deployCupsService?
	# TODO run edit by marcin
	deployCupsService "${name}" "-p" "${JSON}"
	#"${CF_BIN}" cups "${name}" -p "${JSON}" || echo "Service already created. Proceeding with the script"
}

# used for tests
export RETRIEVE_STUBRUNNER_IDS_FUNCTION="${RETRIEVE_STUBRUNNER_IDS_FUNCTION:-retrieveStubRunnerIds}"

function deployStubRunnerBoot() {
	local jarName="${1}"
	local stubRunnerName="${2}"
	local pathToManifest="${3}"
	echo "Deploying Stub Runner. Options jar name [${jarName}], app name [${stubRunnerName}]"
	deployAppNoStart "${stubRunnerName}" "${jarName}" "${ENVIRONMENT}" "${pathToManifest}" "$(retrieveAppName)"
	local prop
	prop="$(${RETRIEVE_STUBRUNNER_IDS_FUNCTION})"
	echo "Found following stub runner ids [${prop}]"
	if [[ "${prop}" != "" ]]; then
		addMultiplePortsSupport "${stubRunnerName}" "${prop}" "${pathToManifest}"
		setEnvVar "${stubRunnerName}" "stubrunner.ids" "${prop}"
	fi
	setEnvVar "${stubRunnerName}" "REPO_WITH_BINARIES" "${REPO_WITH_BINARIES}"
	restartApp "${stubRunnerName}"
}

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
	appGuid="$( "${CF_BIN}" curl "/v2/apps?q=name:${stubRunnerName}" -X GET | jq '.resources[0].metadata.guid' | sed 's/^"\(.*\)"$/\1/' )"
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
		routeGuid="$( "${CF_BIN}" curl -X GET "/v2/routes?q=host:${newHostname}" | jq '.resources[0].metadata.guid' | sed 's/^"\(.*\)"$/\1/' )"
		echo "GUID of the new route is [${routeGuid}]. Will update the mapping for port [${port}]"
		"${CF_BIN}" curl "/v2/route_mappings" -X POST -d "{ \"app_guid\": \"${appGuid}\", \"route_guid\": \"${routeGuid}\", \"app_port\": ${port} }"
		echo "Successfully updated the new route mapping for port [${port}]"
	done
	IFS="${previousIfs}"
}

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
}

function prepareForSmokeTests() {
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
}

function prepareForE2eTests() {
	logInToPaas

	export APPLICATION_URL
	APPLICATION_URL="$(retrieveApplicationUrl | tail -1)"
	echo "Application URL [${APPLICATION_URL}]"
}

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
}

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
}

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
}

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
}

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
}

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
}

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
}

function propagatePropertiesForTests() {
	local projectArtifactId="${1}"
	local serviceType="stubrunner"
	local stubRunnerName
	stubRunnerName="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceType}" '.[$x].services[] | select(.name == $y) | .name' | sed 's/^"\(.*\)"$/\1/')"
	local fileLocation="${OUTPUT_FOLDER}/test.properties}"
	echo "Propagating properties for tests. Project [${projectArtifactId}] stub runner app name [${stubRunnerName}] properties location [${fileLocation}]"
	# retrieve host of the app / stubrunner
	# we have to store them in a file that will be picked as properties
	rm -rf "${fileLocation}"
	local host
	host="$(getAppHostFromPaas "${projectArtifactId}")"
	export APPLICATION_URL="${host}"
	echo "APPLICATION_URL=${host}" >>"${fileLocation}"
	host=$(getAppHostFromPaas "${stubRunnerName}")
	export STUBRUNNER_URL="${host}"
	echo "STUBRUNNER_URL=${host}" >>"${fileLocation}"
	echo "Resolved properties"
	cat "${fileLocation}"
}

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
}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CF_BIN
CF_BIN="${CF_BIN:-cf}"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
# shellcheck source=/dev/null
[[ -f "${__DIR}/projectType/pipeline-jvm.sh" ]] && source "${__DIR}/projectType/pipeline-jvm.sh" ||  \
 echo "No projectType/pipeline-jvm.sh found"

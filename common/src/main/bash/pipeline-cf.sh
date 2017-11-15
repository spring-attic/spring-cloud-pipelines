#!/bin/bash

set -e

function logInToPaas() {
	local user="PAAS_${ENVIRONMENT}_USERNAME"
	local cfUsername="${!user}"
	local pass="PAAS_${ENVIRONMENT}_PASSWORD"
	local cfPassword="${!pass}"
	local org="PAAS_${ENVIRONMENT}_ORG"
	local cfOrg="${!org}"
	local space="PAAS_${ENVIRONMENT}_SPACE"
	local cfSpace="${!space}"
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
	# TODO: This only works if space exists. OK for stage and prod. or test, is there a way to avoid this?
	"${CF_BIN}" login -u "${cfUsername}" -p "${cfPassword}" -o "${cfOrg}" -s "${cfSpace}"

	# If environment is TEST, switch to an isolated, versioned space
	if [[ "${ENVIRONMENT}" == "TEST" ]]; then
		cfSpace=$(getTestSpaceName)
		"${CF_BIN}" create-space "${cfSpace}"
		"${CF_BIN}" target -s "${cfSpace}"
	fi
}

function getTestSpaceName() {
	if [[ "${ENVIRONMENT}" != "TEST" ]]; then
		echo "Current environment is [${ENVIRONMENT}]. Function getTestSpaceName() is invalid for non-test environment"
		return 1;
	fi
	local appName
	appName=$(retrieveAppName)
	local space="PAAS_${ENVIRONMENT}_SPACE"
	local cfSpacePrefix="${!space}"
	local cfSpace="${cfSpacePrefix}"-"${appName}"-"${PIPELINE_VERSION}"
	echo "${cfSpace}"
}

function testCleanup() {
	logInToPaas
	local appName
	appName=$(retrieveAppName)
	local space="PAAS_${ENVIRONMENT}_SPACE"
	local cfSpacePrefix="${!space}"
	cfSpacePrefix="${cfSpacePrefix}"-"${appName}"-
	
	"${CF_BIN}" spaces | grep "${cfSpacePrefix}" | while read -r oldCfSpace ; do
		echo "Deleting leftover space from previous pipeline execution: ${oldCfSpace}"
		"${CF_BIN}" delete-space -f "${oldCfSpace}"
	done
	
}

function testDeploy() {
	# TODO: Consider making it less JVM specific
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)

	# Delete test space, then call loginToPaas, which will recreate it
	testCleanup
	logInToPaas

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
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${LATEST_PROD_VERSION}"
	logInToPaas
	# TODO Add deleteApp here to be sure app is deployed only once
	##########
	##########
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
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates' | sed 's/^"\(.*\)"$/\1/')"
			local coordinatesSeparator=":"
			local PREVIOUS_IFS="${IFS}"
			IFS=${coordinatesSeparator} read -r APP_GROUP_ID APP_ARTIFACT_ID APP_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			downloadAppBinary "${REPO_WITH_BINARIES}" "${APP_GROUP_ID}" "${APP_ARTIFACT_ID}" "${APP_VERSION}"
			deployAppAsService "${APP_ARTIFACT_ID}-${APP_VERSION}" "${serviceName}" "${ENVIRONMENT}"
		;;
		cups)
			#TODO: Can Creds be read from somewhere else? Marcin: "it's just test and maybe stage. If sensitive in stage, can be set manually." Credhub Concourse integration? Other?
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
			local serviceCoordinates
			serviceCoordinates="$(echo "${PARSED_YAML}" |  jq --arg x "${LOWERCASE_ENV}" --arg y "${serviceName}" '.[$x].services[] | select(.name == $y) | .coordinates' | sed 's/^"\(.*\)"$/\1/')"
			local coordinatesSeparator=":"
			local PREVIOUS_IFS="${IFS}"
			IFS="${coordinatesSeparator}" read -r STUBRUNNER_GROUP_ID STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"

			local eurekaName
			eurekaName="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "eureka") | .name' | sed 's/^"\(.*\)"$/\1/')"
			local rabbitMqName
			rabbitMqName="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "rabbitmq") | .name' | sed 's/^"\(.*\)"$/\1/')"

			local parsedStubRunnerUseClasspath
			parsedStubRunnerUseClasspath="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.name == "stubrunner") | .useClasspath' | sed 's/^"\(.*\)"$/\1/')"
			local stubRunnerUseClasspath
			stubRunnerUseClasspath=$(if [[ "${parsedStubRunnerUseClasspath}" == "null" ]]; then
				echo "false";
			else
				echo "${parsedStubRunnerUseClasspath}";
			fi)
			downloadAppBinary "${REPO_WITH_BINARIES}" "${STUBRUNNER_GROUP_ID}" "${STUBRUNNER_ARTIFACT_ID}" "${STUBRUNNER_VERSION}"
			deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES}" "${rabbitMqName}" "${eurekaName}" "${ENVIRONMENT}" "${serviceName}" "${stubRunnerUseClasspath}"
		;;
		*)
			echo "Unknown service type [${serviceType}] for service name [${serviceName}]"
			return 1
		;;
	esac
}

function deleteService() {
	local serviceType
	serviceType=$(toLowerCase "${1}")
	local serviceName="${2}"
	# If service is a cups pointing to an app, delete the app first
	if [[ "${serviceType}" == "app" ]]; then
		# Delete app and route
		"${CF_BIN}" delete -f -r "${serviceName}" || echo "Failed to delete app [${serviceName}]"
	fi
	# Delete the service
	"${CF_BIN}" delete-service -f "${serviceName}" || echo "Failed to delete service [${serviceName}]"
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
	local manifestProfiles
	manifestProfiles="$(getValueFromManifest "${appName}" "profiles")"
	if [[ ! -z "${manifestProfiles}" && "${manifestProfiles}" != "null" ]]; then
		profiles="${profiles},${manifestProfiles}"
	fi

	echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}] and env [${ENVIRONMENT}]"
	deployAppWithName "${appName}" "${jarName}" "${ENVIRONMENT}"

	setEnvVar "${lowerCaseAppName}" 'SPRING_PROFILES_ACTIVE' "${profiles}"
	restartApp "${appName}"
}

# Function to get specific values from app manifest
function getValueFromManifest() {
	local appName="${1}"
	local key="${2}"
	local value

	if [ -z "${PARSED_APP_MANIFEST_YAML}" ]; then
		if [[ ! -f "manifest.yml" ]]; then
			echo "App manifest.yml file not found"
			return 1
		fi
		export PARSED_APP_MANIFEST_YAML
		PARSED_APP_MANIFEST_YAML="$(yaml2json "manifest.yml")"
	fi

	case ${key} in
		profiles)
			value="$(echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .env | .SPRING_PROFILES_ACTIVE' | sed 's/^"\(.*\)"$/\1/')"
		;;
		host)
			value="$(echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .host' | sed 's/^"\(.*\)"$/\1/')"
		;;
		instances)
			value="$(echo "${PARSED_APP_MANIFEST_YAML}" |  jq --arg x "${appName}" '.applications[] | select(.name = $x) | .instances' | sed 's/^"\(.*\)"$/\1/')"
		;;
		*)
			echo "Unknown manifest key [${key}] for app name [${appName}]"
			return 1
	;;
	esac
	echo "${value}"
}

function getAppHostFromPaas() {
	local appName="${1}"
	local lowerCase
	lowerCase="$(toLowerCase "${appName}")"
	"${CF_BIN}" apps | awk -v "app=${lowerCase}" '$1 == app {print($0)}' | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1 | tail -1
}

function deployAppWithName() {
	local appName="${1}"
	local artifactName="${2}"
	local env="${3}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")

	# TODO: getting hostname from manifest - consult with Marcin
	local hostname
	hostname="$(getValueFromManifest "${appName}" "host")"
	if [[ -z "${hostname}" || "${hostname}" == "null" ]]; then
		local hostname="${lowerCaseAppName}"
	fi
	# Even if host is specified in the manifest, append the hostname uuid from the credentials file
	if [[ "${PAAS_HOSTNAME_UUID}" != "" ]]; then
		hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
	fi
	if [[ ${env} != "PROD" ]]; then
		hostname="${hostname}-${LOWERCASE_ENV}"
	fi

	# TODO set "i 1" for test only, leave manifest value for stage and prod
	local instances
	instances="$(getValueFromManifest "${appName}" "instances")"
	if [[ ${env} == "TEST" || -z "${instances}" || "${instances}" == "null" ]]; then
		instances=1
	fi

	echo "Deploying app with name [${lowerCaseAppName}], env [${env}] and host [${hostname}]"
	"${CF_BIN}" push "${lowerCaseAppName}" -p "${OUTPUT_FOLDER}/${artifactName}.${BINARY_EXTENSION}" -n "${hostname}" -i "${instances}" --no-start

	local applicationDomain
	applicationDomain="$(getAppHostFromPaas "${lowerCaseAppName}")"
	echo "Determined that application_domain for [${lowerCaseAppName}] is [${applicationDomain}]"
	# TODO: ask Marcin - what is this env var for?
	# TODO Marcin: "try without it, if it works, delete it"
	setEnvVar "${lowerCaseAppName}" 'APPLICATION_DOMAIN' "${applicationDomain}"

    # TODO: Only needed for Spring Cloud Services
    # TODO: cyi - let user set this in the manifest? would the value ever be different?
    local cfApi
    cfApi=$("${CF_BIN}" api | head -1 | cut -c 25-)
    setEnvVar "${lowerCaseAppName}" 'TRUST_CERTS' "${cfApi}"
}

function deleteApp() {
	local serviceName="${1}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${serviceName}")
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
	local env="${3}"
	echo "Deploying app as service. Options - jar name [${jarName}], app name [${appName}], env [${env}]"
	deployAppWithName "${appName}" "${jarName}" "${env}"
	restartApp "${appName}"
	createServiceWithName "${appName}"
}

function deployBrokeredService() {
        local serviceName="${1}"
        local broker="${2}"
        local plan="${3}"
        local params="${4}"
        if [[ -z "${params}" || "${params}" == "null" ]]; then
	        echo "Deploying [${serviceName}] via Service Broker in [${LOWERCASE_ENV}] env. Options - broker [${broker}], plan [${plan}]"
		    "${CF_BIN}" create-service "${broker}" "${plan}" "${serviceName}"
        else

	        echo "Deploying [${serviceName}] via Service Broker in [${LOWERCASE_ENV}] env. Options - broker [${broker}], plan [${plan}], params:"
	        echo "${params}"
            # Write params to file:
            local destination
            destination="$(pwd)/${OUTPUT_FOLDER}/${serviceName}-service-params.json"
            mkdir -p "${OUTPUT_FOLDER}"
            echo "Writing params to [${destination}]"
            echo "${params}" > "${destination}"
            "${CF_BIN}" create-service "${broker}" "${plan}" "${serviceName}" -c "${destination}"

#           TODO: For create-service, there is a -t tags parameter -  add support for this?
#           TODO: For create-service and cups, do we need to consider updates for services that already exist?
			# TODO: Marcin discussion - decision: hanlde the update using a diff in test-rollback
        fi
}

deployCupsService() {
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
	# TODO - consult Marcin - add below:  || echo "Service already created. Proceeding with the script"
	"${CF_BIN}" cups "${serviceName}" "${cupsOption}" "${cupsValue}"
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

function deployStubRunnerBoot() {
	local jarName="${1}"
	local repoWithJars="${2}"
	local rabbitName="${3}"
	local eurekaName="${4}"
	local env="${5:-test}"
	local stubRunnerName="${6:-stubrunner}"
	local stubRunnerUseClasspath="${7:-false}"
	echo "Deploying Stub Runner. Options jar name [${jarName}], app name [${stubRunnerName}]"
	deployAppWithName "${stubRunnerName}" "${jarName}" "${env}"
	local prop
	prop="$(retrieveStubRunnerIds)"
	echo "Found following stub runner ids [${prop}]"
	setEnvVar "${stubRunnerName}" "stubrunner.ids" "${prop}"
	if [[ "${stubRunnerUseClasspath}" == "false" ]]; then
		setEnvVar "${stubRunnerName}" "stubrunner.repositoryRoot" "${repoWithJars}"
	fi
	if [[ "${rabbitName}" != "" ]]; then
		bindService "${rabbitName}" "${stubRunnerName}"
		setEnvVar "${stubRunnerName}" "spring.rabbitmq.addresses" "\${vcap.services.${rabbitName}.credentials.uri}"
	fi
	if [[ "${eurekaName}" != "" ]]; then
		bindService "${eurekaName}" "${stubRunnerName}"
		setEnvVar "${stubRunnerName}" "eureka.client.serviceUrl.defaultZone" "\${vcap.services.${eurekaName}.credentials.uri:http://127.0.0.1:8761}/eureka/"
	fi
	restartApp "${stubRunnerName}"
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

	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"

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

function performGreenDeployment() {
	local projectGroupId
	projectGroupId="$(retrieveGroupId)"
	local appName
	appName="$(retrieveAppName)"

	# download app
	downloadAppBinary "${REPO_WITH_BINARIES}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"
	# Log in to CF to start deployment
	logInToPaas

	# deploy app
	performGreenDeploymentOfTestedApplication "${appName}"
}

function performGreenDeploymentOfTestedApplication() {
	local appName="${1}"
	local newName="${appName}-venerable"
	echo "Renaming the app from [${appName}] -> [${newName}]"
	local appPresent="no"
	"${CF_BIN}" app "${appName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		"${CF_BIN}" rename "${appName}" "${newName}"
	else
		echo "Will not rename the application cause it's not there"
	fi
	deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}"
}

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
		"${CF_BIN}" stop "${appName}"
	else
		echo "Will not rollback to blue instance cause it's not there"
		return 1
	fi
}

function deleteBlueInstance() {
	local appName
	appName="$(retrieveAppName)"
	# Log in to CF to start deployment
	logInToPaas
	local oldName="${appName}-venerable"
	echo "Deleting the app [${oldName}]"
	local appPresent="no"
	"${CF_BIN}" app "${oldName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		# Delete app only, not route
		"${CF_BIN}" delete "${oldName}" -f
	else
		echo "Will not remove the old application cause it's not there"
	fi
}

function propagatePropertiesForTests() {
	local projectArtifactId="${1}"
	local stubRunnerHost="${2:-stubrunner-${projectArtifactId}}"
	local fileLocation="${3:-${OUTPUT_FOLDER}/test.properties}"
	echo "Propagating properties for tests. Project [${projectArtifactId}] stub runner host [${stubRunnerHost}] properties location [${fileLocation}]"
	# retrieve host of the app / stubrunner
	# we have to store them in a file that will be picked as properties
	rm -rf "${fileLocation}"
	local host=
	host="$(getAppHostFromPaas "${projectArtifactId}")"
	export APPLICATION_URL="${host}"
	echo "APPLICATION_URL=${host}" >>"${fileLocation}"
	host=$(getAppHostFromPaas "${stubRunnerHost}")
	export STUBRUNNER_URL="${host}"
	echo "STUBRUNNER_URL=${host}" >>"${fileLocation}"
	echo "Resolved properties"
	cat "${fileLocation}"
}

function waitForServicesToInitialize() {
	# Wait until services are ready
	while "${CF_BIN}" services | grep 'in progress'
	  do
		sleep 10
		echo "Waiting for services to initialize..."
	  done
	echo "Service initialization - complete"
}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CF_BIN
CF_BIN="${CF_BIN:-cf}"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
# shellcheck source=/dev/null
[[ -f "${__DIR}/projectType/pipeline-jvm.sh" ]] && source "${__DIR}/projectType/pipeline-jvm.sh" ||  \
 echo "No projectType/pipeline-jvm.sh found"

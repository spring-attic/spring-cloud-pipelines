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
	local cfInstalled
	cfInstalled="$(cf --version || echo "false")"
	local cfDownloaded
	cfDownloaded="$(test -r cf && echo "true" || echo "false")"
	echo "CF Installed? [${cfInstalled}], CF Downloaded? [${cfDownloaded}]"
	if [[ ${cfInstalled} == "false" && ${cfDownloaded} == "false" ]]; then
		echo "Downloading Cloud Foundry"
		curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" --fail | tar -zx
		cfDownloaded="true"
	else
		echo "CF is already installed"
	fi

	if [[ ${cfDownloaded} == "true" ]]; then
		echo "Adding CF to PATH"
		PATH=${PATH}:$(pwd)
		chmod +x cf
	fi

	echo "Cloud foundry version"
	cf --version

	echo "Logging in to CF to org [${cfOrg}], space [${cfSpace}]"
	cf api --skip-ssl-validation "${apiUrl}"
	cf login -u "${cfUsername}" -p "${cfPassword}" -o "${cfOrg}" -s "${cfSpace}"
}

function testDeploy() {
	# TODO: Consider making it less JVM specific
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)
	# Log in to PaaS to start deployment
	logInToPaas

	# First delete the app instance to remove all bindings
	deleteAppInstance "${appName}"

	deployServices

	# deploy app
	downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"
	deployAndRestartAppWithNameForSmokeTests "${appName}" "${appName}-${PIPELINE_VERSION}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
	propagatePropertiesForTests "${appName}"
}

function testRollbackDeploy() {
	rm -rf "${OUTPUT_FOLDER}/test.properties"
	local latestProdTag="${1}"
	local projectGroupId
	projectGroupId=$(retrieveGroupId)
	local appName
	appName=$(retrieveAppName)
	# Downloading latest jar
	local LATEST_PROD_VERSION=${latestProdTag#prod/}
	echo "Last prod version equals ${LATEST_PROD_VERSION}"
	downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${projectGroupId}" "${appName}" "${LATEST_PROD_VERSION}"
	logInToPaas
	deployAndRestartAppWithNameForSmokeTests "${appName}" "${appName}-${LATEST_PROD_VERSION}"
	propagatePropertiesForTests "${appName}"
	# Adding latest prod tag
	echo "LATEST_PROD_TAG=${latestProdTag}" >>"${OUTPUT_FOLDER}/test.properties"
}

function deployService() {
	local serviceType
	serviceType=$(toLowerCase "${1}")
	local serviceName="${2}"
	local serviceCoordinates
	serviceCoordinates=$(if [[ "${3}" == "null" ]]; then
		echo "";
	else
		echo "${3}";
	fi)
	local coordinatesSeparator=":"
	case ${serviceType} in
		rabbitmq)
			deployRabbitMq "${serviceName}"
		;;
		mysql)
			deployMySql "${serviceName}"
		;;
		eureka)
			local PREVIOUS_IFS="${IFS}"
			IFS=${coordinatesSeparator} read -r EUREKA_GROUP_ID EUREKA_ARTIFACT_ID EUREKA_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${EUREKA_GROUP_ID}" "${EUREKA_ARTIFACT_ID}" "${EUREKA_VERSION}"
			deployEureka "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${serviceName}" "${ENVIRONMENT}"
		;;
		stubrunner)
			local eurekaName
			eurekaName="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "eureka") | .name' | sed 's/^"\(.*\)"$/\1/')"
			local rabbitMqName
			rabbitMqName="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "rabbitmq") | .name' | sed 's/^"\(.*\)"$/\1/')"
			local PREVIOUS_IFS="${IFS}"
			IFS="${coordinatesSeparator}" read -r STUBRUNNER_GROUP_ID STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<<"${serviceCoordinates}"
			IFS="${PREVIOUS_IFS}"
			local parsedStubRunnerUseClasspath
			parsedStubRunnerUseClasspath="$(echo "${PARSED_YAML}" | jq --arg x "${LOWERCASE_ENV}" '.[$x].services[] | select(.type == "stubrunner") | .useClasspath' | sed 's/^"\(.*\)"$/\1/')"
			local stubRunnerUseClasspath
			stubRunnerUseClasspath=$(if [[ "${parsedStubRunnerUseClasspath}" == "null" ]]; then
				echo "false";
			else
				echo "${parsedStubRunnerUseClasspath}";
			fi)
			downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${STUBRUNNER_GROUP_ID}" "${STUBRUNNER_ARTIFACT_ID}" "${STUBRUNNER_VERSION}"
			deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${rabbitMqName}" "${eurekaName}" "${ENVIRONMENT}" "${serviceName}" "${stubRunnerUseClasspath}"
		;;
		*)
			echo "Unknown service with type [${serviceType}] and name [${serviceName}]"
			return 1
		;;
	esac
}

function deleteService() {
	local serviceType
	serviceType=$(toLowerCase "${1}")
	local serviceName="${2}"
	case ${serviceType} in
		mysql)
			deleteMySql "${serviceName}"
		;;
		rabbitmq)
			deleteRabbitMq "${serviceName}"
		;;
		*)
			deleteServiceWithName "${serviceName}" || echo "Failed to delete service with type [${serviceType}] and name [${serviceName}]"
		;;
	esac
}

function deployRabbitMq() {
	local serviceName="${1:-rabbitmq-github}"
	echo "Waiting for RabbitMQ to start"
	local foundApp
	foundApp=$(serviceExists "rabbitmq" "${serviceName}")
	if [[ "${foundApp}" == "false" ]]; then
		local hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
		(cf cs cloudamqp lemur "${serviceName}" && echo "Started RabbitMQ") ||
		(cf cs p-rabbitmq standard "${serviceName}" && echo "Started RabbitMQ for PCF Dev")
	else
		echo "Service [${serviceName}] already started"
	fi
}

function findAppByName() {
	local serviceName="${1}"
	cf s | awk -v "app=${serviceName}" '$1 == app {print($0)}'
}

function serviceExists() {
	local serviceType="${1}"
	local serviceName="${2}"
	local foundApp
	foundApp=$(findAppByName "${serviceName}")
	if [[ "${foundApp}" == "" ]]; then
		echo "false"
	else
		echo "true"
	fi
}

function deleteMySql() {
	local serviceName="${1:-mysql-github}"
	deleteServiceWithName "${serviceName}"
}

function deleteRabbitMq() {
	local serviceName="${1:-rabbitmq-github}"
	deleteServiceWithName "${serviceName}"
}

function deleteServiceWithName() {
	local serviceName="${1}"
	cf delete -f "${serviceName}" || echo "Failed to delete app [${serviceName}]"
	cf delete-service -f "${serviceName}" || echo "Failed to delete service [${serviceName}]"
}

function deployMySql() {
	local serviceName="${1:-mysql-github}"
	echo "Waiting for MySQL to start"
	local foundApp
	foundApp=$(serviceExists "mysql" "${serviceName}")
	if [[ "${foundApp}" == "false" ]]; then
		local hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
		(cf cs p-mysql 100mb "${serviceName}" && echo "Started MySQL") ||
		(cf cs p-mysql 512mb "${serviceName}" && echo "Started MySQL for PCF Dev")
	else
		echo "Service [${serviceName}] already started"
	fi
}

function deployAndRestartAppWithName() {
	local appName="${1}"
	local jarName="${2}"
	local env="${ENVIRONMENT}"
	echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}]"
	deployAppWithName "${appName}" "${jarName}" "${env}" 'true'
	restartApp "${appName}"
}

function deployAndRestartAppWithNameForSmokeTests() {
	local appName="${1}"
	local jarName="${2}"
	local rabbitName="rabbitmq-${appName}"
	local eurekaName="eureka-${appName}"
	local mysqlName="mysql-${appName}"
	local profiles="cloud,smoke"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	deleteAppInstance "${appName}"
	echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}] and env [${ENVIRONMENT}]"
	deployAppWithName "${appName}" "${jarName}" "${ENVIRONMENT}" 'false'
	bindService "${rabbitName}" "${appName}"
	if [[ "${eurekaName}" != "" ]]; then
		bindService "${eurekaName}" "${appName}"
	fi
	bindService "${mysqlName}" "${appName}"
	setEnvVar "${lowerCaseAppName}" 'spring.profiles.active' "${profiles}"
	restartApp "${appName}"
}

function appHost() {
	local appName="${1}"
	local lowerCase
	lowerCase="$(toLowerCase "${appName}")"
	cf apps | awk -v "app=${lowerCase}" '$1 == app {print($0)}' | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1 | tail -1
}

function deployAppWithName() {
	local appName="${1}"
	local artifactName="${2}"
	local env="${3}"
	local useManifest="${4:-false}"
	local manifestOption
	manifestOption=$(if [[ "${useManifest}" == "false" ]]; then
		echo "--no-manifest";
	else
		echo "";
	fi)
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${appName}")
	local hostname="${lowerCaseAppName}"
	local memory="${APP_MEMORY_LIMIT:-256m}"
	# TODO: This is very JVM specific
	local buildPackUrl="${JAVA_BUILDPACK_URL:-https://github.com/cloudfoundry/java-buildpack.git#v3.8.1}"
	if [[ "${PAAS_HOSTNAME_UUID}" != "" ]]; then
		hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
	fi
	if [[ ${env} != "PROD" ]]; then
		hostname="${hostname}-${env}"
	fi
	echo "Deploying app with name [${lowerCaseAppName}], env [${env}] with manifest [${useManifest}] and host [${hostname}]"
	if [[ ! -z "${manifestOption}" ]]; then
		# TODO: This is very JVM specific
		cf push "${lowerCaseAppName}" -m "${memory}" -i 1 -p "${OUTPUT_FOLDER}/${artifactName}.${BINARY_EXTENSION}" -n "${hostname}" --no-start -b "${buildPackUrl}" "${manifestOption}"
	else
		# TODO: This is very JVM specific
		cf push "${lowerCaseAppName}" -p "${OUTPUT_FOLDER}/${artifactName}.${BINARY_EXTENSION}" -n "${hostname}" --no-start -b "${buildPackUrl}"
	fi
	local applicationDomain
	applicationDomain="$(appHost "${lowerCaseAppName}")"
	echo "Determined that application_domain for [${lowerCaseAppName}] is [${applicationDomain}]"
	setEnvVar "${lowerCaseAppName}" 'APPLICATION_DOMAIN' "${applicationDomain}"
	# TODO: This is very JVM specific
	setEnvVar "${lowerCaseAppName}" 'JAVA_OPTS' '-Djava.security.egd=file:///dev/urandom'
}

function deleteAppInstance() {
	local serviceName="${1}"
	local lowerCaseAppName
	lowerCaseAppName=$(toLowerCase "${serviceName}")
	local APP_NAME="${lowerCaseAppName}"
	echo "Deleting application [${APP_NAME}]"
	cf delete -f "${APP_NAME}" || echo "Failed to delete the app. Continuing with the script"
}

function setEnvVarIfMissing() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}] if missing"
	cf env "${appName}" | grep "${key}" || setEnvVar appName key value
}

function setEnvVar() {
	local appName="${1}"
	local key="${2}"
	local value="${3}"
	echo "Setting env var [${key}] -> [${value}] for app [${appName}]"
	cf set-env "${appName}" "${key}" "${value}"
}

function restartApp() {
	local appName="${1}"
	echo "Restarting app with name [${appName}]"
	cf restart "${appName}"
}

function deployEureka() {
	local jarName="${1}"
	local appName="${2}"
	local env="${3}"
	echo "Deploying Eureka. Options - jar name [${jarName}], app name [${appName}], env [${env}]"
	deployAppWithName "${appName}" "${jarName}" "${env}"
	restartApp "${appName}"
	createServiceWithName "${appName}"
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
	deployAppWithName "${stubRunnerName}" "${jarName}" "${env}" "false"
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
	echo "Binding service [${serviceName}] to app [${appName}]"
	cf bind-service "${appName}" "${serviceName}"
}

function createServiceWithName() {
	local name="${1}"
	echo "Creating service with name [${name}]"
	APPLICATION_DOMAIN="$(cf apps | grep "${name}" | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1)"
	JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
	cf create-user-provided-service "${name}" -p "${JSON}" || echo "Service already created. Proceeding with the script"
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

	downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"

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
	downloadAppBinary "${REPO_WITH_BINARIES_FOR_UPLOAD}" "${projectGroupId}" "${appName}" "${PIPELINE_VERSION}"
	# Log in to CF to start deployment
	logInToPaas

	# deploy app
	performProductionDeploymentOfTestedApplication "${appName}"
}

function performProductionDeploymentOfTestedApplication() {
	local appName="${1}"
	local newName="${appName}-venerable"
	echo "Renaming the app from [${appName}] -> [${newName}]"
	local appPresent="no"
	cf app "${appName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		cf rename "${appName}" "${newName}"
	else
		echo "Will not rename the application cause it's not there"
	fi
	deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}"
}

function completeSwitchOver() {
	local appName
	appName="$(retrieveAppName)"
	# Log in to CF to start deployment
	logInToPaas
	local oldName="${appName}-venerable"
	echo "Deleting the app [${oldName}]"
	cf app "${oldName}" && appPresent="yes"
	if [[ "${appPresent}" == "yes" ]]; then
		cf delete "${oldName}" -f
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
	host="$(appHost "${projectArtifactId}")"
	export APPLICATION_URL="${host}"
	echo "APPLICATION_URL=${host}" >>"${fileLocation}"
	host=$(appHost "${stubRunnerHost}")
	export STUBRUNNER_URL="${host}"
	echo "STUBRUNNER_URL=${host}" >>"${fileLocation}"
	echo "Resolved properties"
	cat "${fileLocation}"
}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
# shellcheck source=/dev/null
[[ -f "${__DIR}/projectType/pipeline-jvm.sh" ]] && source "${__DIR}/projectType/pipeline-jvm.sh" ||  \
 echo "No projectType/pipeline-jvm.sh found"

#!/bin/bash
set -e

function logInToPaas() {
    local redownloadInfra="${REDOWNLOAD_INFRA}"
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
    CF_INSTALLED="$( cf --version || echo "false" )"
    CF_DOWNLOADED="$( test -r cf && echo "true" || echo "false" )"
    echo "CF Installed? [${CF_INSTALLED}], CF Downloaded? [${CF_DOWNLOADED}]"
    if [[ ${CF_INSTALLED} == "false" && (${CF_DOWNLOADED} == "false" || ${CF_DOWNLOADED} == "true" && ${redownloadInfra} == "true") ]]; then
        echo "Downloading Cloud Foundry"
        curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" --fail | tar -zx
        CF_DOWNLOADED="true"
    else
        echo "CF is already installed or was already downloaded but the flag to redownload was disabled"
    fi

    if [[ ${CF_DOWNLOADED} == "true" ]]; then
        echo "Adding CF to PATH"
        PATH=${PATH}:`pwd`
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
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    # First delete the app instance to remove all bindings
    deleteAppInstance "${appName}"

    # TODO: Consider picking services and apps from file
    # services
    export UNIQUE_RABBIT_NAME="rabbitmq-${appName}"
    deployService "RABBITMQ" "${UNIQUE_RABBIT_NAME}"
    export UNIQUE_MYSQL_NAME="mysql-${appName}"
    deleteService "MYSQL" "${UNIQUE_MYSQL_NAME}"
    deployService "MYSQL" "${UNIQUE_MYSQL_NAME}"

    # dependant apps
    if [[ "${REDEPLOY_INFRA}" == "true" ]]; then
        export UNIQUE_EUREKA_NAME="eureka-${appName}"
    fi
    deployService "EUREKA" "${UNIQUE_EUREKA_NAME}"
    export UNIQUE_STUBRUNNER_NAME="stubrunner-${appName}"
    deployService "STUBRUNNER" "${UNIQUE_STUBRUNNER_NAME}"

    # deploy app
    downloadAppBinary 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${PIPELINE_VERSION}
    deployAndRestartAppWithNameForSmokeTests ${appName} "${appName}-${PIPELINE_VERSION}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
    propagatePropertiesForTests ${appName}
}

function testRollbackDeploy() {
    rm -rf ${OUTPUT_FOLDER}/test.properties
    local latestProdTag="${1}"
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )
    # Downloading latest jar
    LATEST_PROD_VERSION=${latestProdTag#prod/}
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    downloadAppBinary 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${LATEST_PROD_VERSION}
    logInToPaas
    deployAndRestartAppWithNameForSmokeTests ${appName} "${appName}-${LATEST_PROD_VERSION}"
    propagatePropertiesForTests ${appName}
    # Adding latest prod tag
    echo "LATEST_PROD_TAG=${latestProdTag}" >> ${OUTPUT_FOLDER}/test.properties
}

function deployService() {
    local serviceType="${1}"
    local serviceName="${2}"
    case ${serviceType} in
    RABBITMQ)
      deployRabbitMq "${serviceName}"
      ;;
    MYSQL)
      deployMySql "${serviceName}"
      ;;
    EUREKA)
      downloadAppBinary ${REDEPLOY_INFRA} ${REPO_WITH_BINARIES} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
      deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${serviceName}" "${ENVIRONMENT}"
      ;;
    STUBRUNNER)
      downloadAppBinary 'true' ${REPO_WITH_BINARIES} ${STUBRUNNER_GROUP_ID} ${STUBRUNNER_ARTIFACT_ID} ${STUBRUNNER_VERSION}
      deployStubRunnerBoot 'true' "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${ENVIRONMENT}" "${UNIQUE_STUBRUNNER_NAME}"
      ;;
    *)
      echo "Unknown service"
      return 1
      ;;
    esac
}

function deleteService() {
    local serviceType="${1}"
    local serviceName="${2}"
    case ${serviceType} in
    MYSQL)
      deleteMySql "${serviceName}"
      ;;
    *)
      echo "Unknown service"
      return 1
      ;;
    esac
}

function deployRabbitMq() {
    local serviceName="${1:-rabbitmq-github}"
    echo "Waiting for RabbitMQ to start"
    local foundApp=`cf s | awk -v "app=${serviceName}" '$1 == app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
        (cf cs cloudamqp lemur "${serviceName}" && echo "Started RabbitMQ") ||
        (cf cs p-rabbitmq standard "${serviceName}" && echo "Started RabbitMQ for PCF Dev")
    else
        echo "Service [${serviceName}] already started"
    fi
}

function deleteMySql() {
    local serviceName="${1:-mysql-github}"
    cf delete-service -f ${serviceName}
}

function deployMySql() {
    local serviceName="${1:-mysql-github}"
    echo "Waiting for MySQL to start"
    local foundApp=`cf s | awk -v "app=${serviceName}" '$1 == app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
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
    local eurekaName=""
    if [[ "${REDEPLOY_INFRA}" == "true" ]]; then
        eurekaName="eureka-${appName}"
    fi
    local mysqlName="mysql-${appName}"
    local profiles="cloud,smoke"
    local lowerCaseAppName=$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )
    deleteAppInstance "${appName}"
    echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}] and env [${env}]"
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
    local lowerCase="$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )"
    local APP_HOST=`cf apps | awk -v "app=${lowerCase}" '$1 == app {print($0)}' | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
    echo "${APP_HOST}" | tail -1
}

function deployAppWithName() {
    local appName="${1}"
    local jarName="${2}"
    local env="${3}"
    local useManifest="${4:-false}"
    local manifestOption=$( if [[ "${useManifest}" == "false" ]] ; then echo "--no-manifest"; else echo "" ; fi )
    local lowerCaseAppName=$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )
    local hostname="${lowerCaseAppName}"
    local memory="${APP_MEMORY_LIMIT:-256m}"
    local buildPackUrl="${JAVA_BUILDPACK_URL:-https://github.com/cloudfoundry/java-buildpack.git#v3.8.1}"
    if [[ "${PAAS_HOSTNAME_UUID}" != "" ]]; then
        hostname="${hostname}-${PAAS_HOSTNAME_UUID}"
    fi
    if [[ ${env} != "PROD" ]]; then
        hostname="${hostname}-${env}"
    fi
    echo "Deploying app with name [${lowerCaseAppName}], env [${env}] with manifest [${useManifest}] and host [${hostname}]"
    if [[ ! -z "${manifestOption}" ]]; then
        cf push "${lowerCaseAppName}" -m "${memory}" -i 1 -p "${OUTPUT_FOLDER}/${jarName}.jar" -n "${hostname}" --no-start -b "${buildPackUrl}" ${manifestOption}
    else
        cf push "${lowerCaseAppName}" -p "${OUTPUT_FOLDER}/${jarName}.jar" -n "${hostname}" --no-start -b "${buildPackUrl}"
    fi
    APPLICATION_DOMAIN="$( appHost ${lowerCaseAppName} )"
    echo "Determined that application_domain for [${lowerCaseAppName}] is [${APPLICATION_DOMAIN}]"
    setEnvVar "${lowerCaseAppName}" 'APPLICATION_DOMAIN' "${APPLICATION_DOMAIN}"
    setEnvVar "${lowerCaseAppName}" 'JAVA_OPTS' '-Djava.security.egd=file:///dev/urandom'
}

function deleteAppInstance() {
    local serviceName="${1}"
    local lowerCaseAppName=$( echo "${serviceName}" | tr '[:upper:]' '[:lower:]' )
    local APP_NAME="${lowerCaseAppName}"
    echo "Deleting application [${APP_NAME}]"
    cf delete -f ${APP_NAME} || echo "Failed to delete the app. Continuing with the script"
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
    local redeploy="${1}"
    local jarName="${2}"
    local appName="${3}"
    local env="${4}"
    echo "Deploying Eureka. Options - redeploy [${redeploy}], jar name [${jarName}], app name [${appName}], env [${env}]"
    local fileExists="true"
    local fileName="`pwd`/${OUTPUT_FOLDER}/${jarName}.jar"
    if [[ ! -f "${fileName}" ]]; then
        fileExists="false"
    fi
    if [[ ${fileExists} == "false" || ( ${fileExists} == "true" && ${redeploy} == "true" ) ]]; then
        deployAppWithName "${appName}" "${jarName}" "${env}"
        restartApp "${appName}"
        createServiceWithName "${appName}"
    else
        echo "Current folder is [`pwd`]; The [${fileName}] exists [${fileExists}]; redeploy flag was set [${redeploy}]. Skipping deployment"
    fi
}

function deployStubRunnerBoot() {
    local redeploy="${1}"
    local jarName="${2}"
    local repoWithJars="${3}"
    local rabbitName="${4}"
    local eurekaName="${5}"
    local env="${6:-test}"
    local stubRunnerName="${7:-stubrunner}"
    local fileExists="true"
    local fileName="`pwd`/${OUTPUT_FOLDER}/${jarName}.jar"
    local stubRunnerUseClasspath="${STUBRUNNER_USE_CLASSPATH:-false}"
    if [[ ! -f "${fileName}" ]]; then
        fileExists="false"
    fi
    echo "Deploying Stub Runner. Options - redeploy [${redeploy}], jar name [${jarName}], app name [${stubRunnerName}]"
    if [[ ${fileExists} == "false" || ( ${fileExists} == "true" && ${redeploy} == "true" ) ]]; then
        deployAppWithName "${stubRunnerName}" "${jarName}" "${env}" "false"
        local prop="$( retrieveStubRunnerIds )"
        echo "Found following stub runner ids [${prop}]"
        setEnvVar "${stubRunnerName}" "stubrunner.ids" "${prop}"
        if [[ "${stubRunnerUseClasspath}" == "false" ]]; then
            setEnvVar "${stubRunnerName}" "stubrunner.repositoryRoot" "${repoWithJars}"
        fi
        bindService "${rabbitName}" "${stubRunnerName}"
        setEnvVar "${stubRunnerName}" "spring.rabbitmq.addresses" "\${vcap.services.${rabbitName}.credentials.uri}"
        if [[ "${eurekaName}" != "" ]]; then
            bindService "${eurekaName}" "${stubRunnerName}"
            setEnvVar "${stubRunnerName}" "eureka.client.serviceUrl.defaultZone" "\${vcap.services.${eurekaName}.credentials.uri:http://127.0.0.1:8761}/eureka/"
        fi
        restartApp "${stubRunnerName}"
    else
        echo "Current folder is [`pwd`]; The [${fileName}] exists [${fileExists}]; redeploy flag was set [${redeploy}]. Skipping deployment"
    fi
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
    APPLICATION_DOMAIN=`cf apps | grep ${name} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
    JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
    cf create-user-provided-service "${name}" -p "${JSON}" || echo "Service already created. Proceeding with the script"
}

# Function that executes integration tests
function runSmokeTests() {
    local applicationHost="${APPLICATION_URL}"
    local stubrunnerHost="${STUBRUNNER_URL}"
    echo "Running smoke tests"
    echo "Application URL [${APPLICATION_URL}]"
    echo "StubRunner URL [${STUBRUNNER_URL}]"

    LATEST_PROD_VERSION=$( extractVersionFromProdTag ${LATEST_PROD_TAG} )
    echo "Last prod version equals ${LATEST_PROD_VERSION}"

    if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
        if [[ "${CI}" == "CONCOURSE" ]]; then
            ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS} || ( echo "$( printTestResults )" && return 1)
        else
            ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS}
        fi
    elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        if [[ "${CI}" == "CONCOURSE" ]]; then
            ./gradlew smoke -PnewVersion=${PIPELINE_VERSION} -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS} || ( echo "$( printTestResults )" && return 1)
        else
            ./gradlew smoke -PnewVersion=${PIPELINE_VERSION} -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS}
        fi
    else
        echo "Unsupported project build tool"
        return 1
    fi
}

function prepareForSmokeTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    propagatePropertiesForTests ${appName}
    readTestPropertiesFromFile
    echo "Application URL [${APPLICATION_URL}]"
    echo "StubRunner URL [${STUBRUNNER_URL}]"
    echo "Latest production tag [${LATEST_PROD_TAG}]"
}

function readTestPropertiesFromFile() {
    local fileLocation="${1:-${OUTPUT_FOLDER}/test.properties}"
    if [ -f "${fileLocation}" ]
    then
      echo "${fileLocation} found."
      while IFS='=' read -r key value
      do
        key=$(echo ${key} | tr '.' '_')
        eval "${key}='${value}'"
      done < "${fileLocation}"
    else
      echo "${fileLocation} not found."
    fi
}

function stageDeploy() {
    # TODO: Consider making it less JVM specific
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    # TODO: Consider picking services and apps from file
    # services
    deployService "RABBITMQ" "rabbitmq-github"
    deployService "MYSQL" "mysql-github"
    deployService "EUREKA" "${EUREKA_ARTIFACT_ID}"

    downloadAppBinary 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${PIPELINE_VERSION}

    # deploy app
    deployAndRestartAppWithName ${appName} "${appName}-${PIPELINE_VERSION}"
    propagatePropertiesForTests ${appName}
}

function prepareForE2eTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    appName=$( retrieveAppName )
    echo "Project artifactId is ${appName}"
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    propagatePropertiesForTests ${appName}
    readTestPropertiesFromFile
    echo "Application URL [${APPLICATION_URL}]"
}


function performGreenDeployment() {
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )

    # download app
    downloadAppBinary 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${PIPELINE_VERSION}
    # Log in to CF to start deployment
    logInToPaas

    # deploying infra
    # TODO: most likely rabbitmq / eureka / db would be there on production; this remains for demo purposes
    deployRabbitMq
    deployMySql "mysql-github-analytics"
    downloadAppBinary ${REDEPLOY_INFRA} ${REPO_WITH_BINARIES} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
    deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${EUREKA_ARTIFACT_ID}"

    # deploy app
    performGreenDeploymentOfTestedApplication "${appName}"
}

function performGreenDeploymentOfTestedApplication() {
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
    deployAndRestartAppWithName "${appName}" "${appName}-${PIPELINE_VERSION}" "PROD"
}

function deleteBlueInstance() {
    local appName=$( retrieveAppName )
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
    local host=$( appHost "${projectArtifactId}" )
    export APPLICATION_URL="${host}"
    echo "APPLICATION_URL=${host}" >> ${fileLocation}
    host=$( appHost "${stubRunnerHost}" )
    export STUBRUNNER_URL="${host}"
    echo "STUBRUNNER_URL=${host}" >> ${fileLocation}
    echo "Resolved properties"
    cat ${fileLocation}
}

# TODO: Make this removeable
# We have the same application example for both CF & Kubernetes. In CF we don't need
# docker so we're disabling those tasks. However normally the `deploy` should already do
# all that's necessary to deploy a binary (whatever that binary is)
if [[ ! -z "${BUILD_OPTIONS}" ]]; then
    export BUILD_OPTIONS="${BUILD_OPTIONS} -DskipDocker"
else
    export BUILD_OPTIONS="-DskipDocker"
fi

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
[[ -f "${__DIR}/projectType/pipeline-jvm.sh" ]] && source "${__DIR}/projectType/pipeline-jvm.sh" || \
    echo "No projectType/pipeline-jvm.sh found"
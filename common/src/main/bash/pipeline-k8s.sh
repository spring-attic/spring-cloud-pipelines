#!/bin/bash
set -e
set -x

# TODO: REMOVE THIS :(
DEFAULT_TIMEOUT=150

function logInToPaas() {
    local -r redownloadInfra="${REDOWNLOAD_INFRA}"
    local -r ca="PAAS_${ENVIRONMENT}_CA"
    local -r k8sCa="${!ca}"
    local -r clientCert="PAAS_${ENVIRONMENT}_CLIENT_CERT"
    local -r k8sClientCert="${!clientCert}"
    local -r clientKey="PAAS_${ENVIRONMENT}_CLIENT_KEY"
    local -r k8sClientKey="${!clientKey}"
    local -r clusterName="PAAS_${ENVIRONMENT}_CLUSTER_NAME"
    local -r k8sClusterName="${!clusterName}"
    local -r clusterUser="PAAS_${ENVIRONMENT}_CLUSTER_USERNAME"
    local -r k8sClusterUser="${!clusterUser}"
    local -r systemName="PAAS_${ENVIRONMENT}_SYSTEM_NAME"
    local -r k8sSystemName="${!systemName}"
    local -r api="PAAS_${ENVIRONMENT}_API_URL"
    local -r apiUrl="${!api:-192.168.99.100:8443}"
    local CLI_INSTALLED="$( kubectl version || echo "false" )"
    local CLI_DOWNLOADED="$( test -r kubectl && echo "true" || echo "false" )"
    echo "CLI Installed? [${CLI_INSTALLED}], CLI Downloaded? [${CLI_DOWNLOADED}]"
    if [[ ${CLI_INSTALLED} == "false" && (${CLI_DOWNLOADED} == "false" || ${CLI_DOWNLOADED} == "true" && ${redownloadInfra} == "true") ]]; then
        echo "Downloading CLI"
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl --fail
        local CLI_DOWNLOADED="true"
    else
        echo "CLI is already installed or was already downloaded but the flag to redownload was disabled"
    fi

    if [[ ${CLI_DOWNLOADED} == "true" ]]; then
        echo "Adding CLI to PATH"
        PATH=${PATH}:`pwd`
        chmod +x kubectl
    fi

    echo "Logging in to Kubernetes API [${apiUrl}], with cluster name [${k8sClusterName}] and user [${k8sClusterUser}]"
    kubectl config set-cluster ${k8sClusterName} --server=https://${apiUrl} --certificate-authority=${k8sCa}
    kubectl config set-credentials ${k8sClusterUser} --certificate-authority=${k8sCa} --client-key=${k8sClientKey} --client-certificate=${k8sClientCert}
    kubectl config set-context ${k8sSystemName} --cluster=${k8sClusterName} --user=${k8sClusterUser}
    kubectl config use-context ${k8sSystemName}

    echo "CLI version"
    kubectl version
}

function testDeploy() {
    # TODO: Consider making it less JVM specific
    local -r projectGroupId=$( retrieveGroupId )
    local -r appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    deployServices

    # deploy app
    deployAndRestartAppWithNameForSmokeTests "${appName}-${LOWER_CASE_ENV}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
    # TODO: FIX THIS :|
    echo "Waiting for the app to start"
    sleep ${DEFAULT_TIMEOUT}
}

function testRollbackDeploy() {
    rm -rf ${OUTPUT_FOLDER}/test.properties
    local -r latestProdTag="${1}"
    local -r projectGroupId=$( retrieveGroupId )
    local -r appName=$( retrieveAppName )
    # Downloading latest jar
    LATEST_PROD_VERSION=${latestProdTag#prod/}
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    downloadAppArtifact 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${LATEST_PROD_VERSION}
    logInToPaas
    deployAndRestartAppWithNameForSmokeTests ${appName} "${appName}-${LATEST_PROD_VERSION}"
    # Adding latest prod tag
    echo "LATEST_PROD_TAG=${latestProdTag}" >> ${OUTPUT_FOLDER}/test.properties
}

function deployService() {
    local -r serviceType=$( toLowerCase "${1}" )
    local -r serviceName="${2}"
    local -r serviceCoordinates=$( if [[ "${3}" == "null" ]] ; then echo ""; else echo "${3}" ; fi )
    echo "Will deploy service with type [${serviceType}] name [${serviceName}] and coordinates [${serviceCoordinates}]"
    case ${serviceType} in
    rabbitmq)
      deployRabbitMq "${serviceName}"
      ;;
    mysql)
      deployMySql "${serviceName}"
      ;;
    eureka)
      PREVIOUS_IFS="${IFS}"
      IFS=: read -r EUREKA_GROUP_ID EUREKA_ARTIFACT_ID EUREKA_VERSION <<< "${serviceCoordinates}"
      IFS="${PREVIOUS_IFS}"
      deployEureka "${EUREKA_ARTIFACT_ID}:${EUREKA_VERSION}" "${serviceName}"
      ;;
    stubrunner)
      UNIQUE_EUREKA_NAME="$( echo ${PARSED_YAML} | jq --arg x ${LOWER_CASE_ENV} '.[$x].services[] | select(.type == "eureka") | .name' | sed 's/^"\(.*\)"$/\1/' )"
      UNIQUE_RABBIT_NAME="$( echo ${PARSED_YAML} | jq --arg x ${LOWER_CASE_ENV} '.[$x].services[] | select(.type == "rabbitmq") | .name' | sed 's/^"\(.*\)"$/\1/' )"
      PREVIOUS_IFS="${IFS}"
      IFS=: read -r STUBRUNNER_GROUP_ID STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<< "${serviceCoordinates}"
      IFS="${PREVIOUS_IFS}"
      PARSED_STUBRUNNER_USE_CLASSPATH="$( echo ${PARSED_YAML} | jq --arg x ${LOWER_CASE_ENV} '.[$x].services[] | select(.type == "stubrunner") | .useClasspath' | sed 's/^"\(.*\)"$/\1/' )"
      STUBRUNNER_USE_CLASSPATH=$( if [[ "${PARSED_STUBRUNNER_USE_CLASSPATH}" == "null" ]] ; then echo "false"; else echo "${PARSED_STUBRUNNER_USE_CLASSPATH}" ; fi )
      deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}:${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_STUBRUNNER_NAME}"
      ;;
    *)
      echo "Unknown service [${serviceType}]"
      return 1
      ;;
    esac
}

function deleteService() {
    local -r serviceType="${1}"
    local -r serviceName="${2}"
    echo "Deleting all mysql related services with name [${serviceName}]"
    deleteAppByName ${serviceName}
}

function deployRabbitMq() {
    local -r serviceName="${1:-rabbitmq-github}"
    echo "Waiting for RabbitMQ to start"
    local -r foundApp=`kubectl get pods -o wide -l app=${serviceName} | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        local -r deploymentFile="${__ROOT}/k8s/rabbitmq.yml"
        local -r serviceFile="${__ROOT}/k8s/rabbitmq-service.yml"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
        substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
        if [[ "${ENVIRONMENT}" == "TEST" ]]; then
            deleteAppByFile "${deploymentFile}"
            deleteAppByFile "${serviceFile}"
        fi
        replaceApp "${deploymentFile}"
        replaceApp "${serviceFile}"
    else
        echo "Service [${serviceName}] already started"
    fi
}

function deployApp() {
    local -r fileName="${1}"
    kubectl create -f "${fileName}"
}

function replaceApp() {
    local -r fileName="${1}"
    kubectl replace --force -f "${fileName}"
}

function deleteAppByName() {
    local -r serviceName="${1}"
    kubectl delete secret "${serviceName}" || echo "Failed to delete secret [${serviceName}]. Continuing with the script"
    kubectl delete persistentvolumeclaim "${serviceName}"  || echo "Failed to delete persistentvolumeclaim [${serviceName}]. Continuing with the script"
    kubectl delete pod "${serviceName}" || echo "Failed to delete service [${serviceName}]. Continuing with the script"
    kubectl delete deployment "${serviceName}" || echo "Failed to delete deployment [${serviceName}] . Continuing with the script"
    kubectl delete service "${serviceName}" || echo "Failed to delete service [${serviceName}]. Continuing with the script"
}

function deleteAppByFile() {
    local -r file="${1}"
    kubectl delete -f ${file} || echo "Failed to delete app by [${file}] file. Continuing with the script"
}

function substituteVariables() {
    local -r variableName="${1}"
    local -r substitution="${2}"
    local -r escapedSubstitution=$( escapeValueForSed "${substitution}" )
    local -r fileName="${3}"
    #echo "Changing [${variableName}] -> [${escapedSubstitution}] for file [${fileName}]"
    sed -i "s/{{${variableName}}}/${escapedSubstitution}/" ${fileName}
}

function deleteMySql() {
    local -r serviceName="${1:-mysql-github}"
    echo "Deleting all mysql related services with name [${serviceName}]"
    deleteAppByName ${serviceName}
}

function deployMySql() {
    local -r serviceName="${1:-mysql-github}"
    echo "Waiting for MySQL to start"
    local -r foundApp=`kubectl get pods -o wide -l app=${serviceName} | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        local -r deploymentFile="${__ROOT}/k8s/mysql.yml"
        local -r serviceFile="${__ROOT}/k8s/mysql-service.yml"
        echo "Generating secret with name [${serviceName}]"
        kubectl delete secret "${serviceName}" || echo "Failed to delete secret [${serviceName}]. Continuing with the script"
        kubectl create secret generic "${serviceName}" --from-literal=username="${MYSQL_USER}" --from-literal=password="${MYSQL_PASSWORD}" --from-literal=rootpassword="${MYSQL_ROOT_PASSWORD}"
        kubectl label secrets "${serviceName}" env="${LOWER_CASE_ENV}"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
        substituteVariables "mysqlDatabase" "${MYSQL_DATABASE}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
        substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
        if [[ "${ENVIRONMENT}" == "TEST" ]]; then
            deleteAppByFile "${deploymentFile}"
            deleteAppByFile "${serviceFile}"
        fi
        replaceApp "${deploymentFile}"
        replaceApp "${serviceFile}"
    else
        echo "Service [${serviceName}] already started"
    fi
}

function deployAndRestartAppWithName() {
    local -r appName="${1}"
    local -r jarName="${2}"
    local -r env="${LOWER_CASE_ENV}"
    echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}]"
    deployAppWithName "${appName}" "${jarName}" "${env}" 'true'
    restartApp "${appName}"
}

function deployAndRestartAppWithNameForSmokeTests() {
    local -r appName="${1}"
    local -r rabbitName="${2}"
    local -r eurekaName="${3}"
    local -r mysqlName="${4}"
    local -r profiles="smoke"
    local -r lowerCaseAppName=$( toLowerCase "${appName}" )
    local -r deploymentFile="deployment.yml"
    local -r serviceFile="service.yml"
    local -r systemProps="-Dspring.profiles.active=${profiles}"
    local -r systemProps="${systemProps} -DSPRING_RABBITMQ_ADDRESSES=${rabbitName} -Deureka.client.serviceUrl.defaultZone=http://${eurekaName}:8761/eureka"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "version" "${PIPELINE_VERSION}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "systemProps" "${systemProps}" "${deploymentFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
    deleteAppByFile "${deploymentFile}"
    deleteAppByFile "${serviceFile}"
    deployApp "${deploymentFile}"
    deployApp "${serviceFile}"
    kubectl label deployment "${appName}" env="${LOWER_CASE_ENV}"
    kubectl label service "${appName}" env="${LOWER_CASE_ENV}"
}

function deployAndRestartAppWithNameForE2ETests() {
    local -r appName="${1}"
    local -r rabbitName="${2}"
    local -r eurekaName="${3}"
    local -r mysqlName="${4}"
    local -r profiles="smoke"
    local -r lowerCaseAppName=$( toLowerCase "${appName}" )
    local -r deploymentFile="deployment.yml"
    local -r serviceFile="service.yml"
    local -r systemProps="-Dspring.profiles.active=${profiles}"
    local -r systemProps="${systemProps} -DSPRING_RABBITMQ_ADDRESSES=${rabbitName} -Deureka.client.serviceUrl.defaultZone=http://${eurekaName}:8761/eureka"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "version" "${PIPELINE_VERSION}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "systemProps" "${systemProps}" "${deploymentFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
    deleteAppByFile "${deploymentFile}"
    deleteAppByFile "${serviceFile}"
    deployApp "${deploymentFile}"
    deployApp "${serviceFile}"
    kubectl label deployment "${appName}" env="${LOWER_CASE_ENV}"
    kubectl label service "${appName}" env="${LOWER_CASE_ENV}"
}

function deployAppWithName() {
    local -r appName="${1}"
    local -r jarName="${2}"
    local -r env="${3}"
    local -r useManifest="${4:-false}"
    local -r manifestOption=$( if [[ "${useManifest}" == "false" ]] ; then echo "--no-manifest"; else echo "" ; fi )
    local -r lowerCaseAppName=$( toLowerCase "${appName}" )
    local hostname="${lowerCaseAppName}"
    local -r memory="${APP_MEMORY_LIMIT:-256m}"
    local -r buildPackUrl="${JAVA_BUILDPACK_URL:-https://github.com/cloudfoundry/java-buildpack.git#v3.8.1}"
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

function toLowerCase() {
    local -r string=${1}
    echo "${appName}" | tr '[:upper:]' '[:lower:]'
}

function lowerCaseEnv() {
    local -r string=${1}
    echo "${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]'
}

function deleteAppInstance() {
    local -r serviceName="${1}"
    local -r lowerCaseAppName=$( toLowerCase "${serviceName}" )
    echo "Deleting application [${lowerCaseAppName}]"
    deleteAppByName "${lowerCaseAppName}"
}

function setEnvVarIfMissing() {
    local -r appName="${1}"
    local -r key="${2}"
    local -r value="${3}"
    echo "Setting env var [${key}] -> [${value}] for app [${appName}] if missing"
    cf env "${appName}" | grep "${key}" || setEnvVar appName key value
}

function setEnvVar() {
    local -r appName="${1}"
    local -r key="${2}"
    local -r value="${3}"
    echo "Setting env var [${key}] -> [${value}] for app [${appName}]"
    cf set-env "${appName}" "${key}" "${value}"
}

function restartApp() {
    local -r appName="${1}"
    echo "Restarting app with name [${appName}]"
    cf restart "${appName}"
}

function deployEureka() {
    local -r imageName="${1}"
    local -r appName="${2}"
    echo "Deploying Eureka. Options - image name [${imageName}], app name [${appName}], env [${ENVIRONMENT}]"
    local -r deploymentFile="${__ROOT}/k8s/eureka.yml"
    local -r serviceFile="${__ROOT}/k8s/eureka-service.yml"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
    substituteVariables "eurekaImg" "${imageName}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
    if [[ "${ENVIRONMENT}" == "TEST" ]]; then
        deleteAppByFile "${deploymentFile}"
        deleteAppByFile "${serviceFile}"
    fi
    replaceApp "${deploymentFile}"
    replaceApp "${serviceFile}"
    # TODO: FIX THIS :|
    echo "Waiting for the app to start"
    sleep ${DEFAULT_TIMEOUT}
}

function escapeValueForSed() {
    echo "${1//\//\\/}"
}

function deployStubRunnerBoot() {
    local -r imageName="${1}"
    # TODO: Add passing of properties to docker images
    local -r repoWithJars="${2}"
    local -r rabbitName="${3}"
    local -r eurekaName="${4}"
    local -r stubRunnerName="${5:-stubrunner}"
    local -r fileExists="true"
    local -r stubRunnerUseClasspath="${STUBRUNNER_USE_CLASSPATH:-false}"
    echo "Deploying Stub Runner. Options - image name [${imageName}], app name [${stubRunnerName}]"
    local -r prop="$( retrieveStubRunnerIds )"
    echo "Found following stub runner ids [${prop}]"
    local -r deploymentFile="${__ROOT}/k8s/stubrunner.yml"
    local -r serviceFile="${__ROOT}/k8s/stubrunner-service.yml"
    if [[ "${stubRunnerUseClasspath}" == "false" ]]; then
        substituteVariables "repoWithJars" "${repoWithJars}" "${deploymentFile}"
    else
        substituteVariables "repoWithJars" "" "${deploymentFile}"
    fi
    substituteVariables "appName" "${stubRunnerName}" "${deploymentFile}"
    substituteVariables "stubrunnerImg" "${imageName}" "${deploymentFile}"
    substituteVariables "rabbitAppName" "${rabbitName}" "${deploymentFile}"
    substituteVariables "eurekaAppName" "${eurekaName}" "${deploymentFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${deploymentFile}"
    if [[ "${prop}" == "false" ]]; then
        substituteVariables "stubrunnerIds" "${prop}" "${deploymentFile}"
    else
        substituteVariables "stubrunnerIds" "" "${deploymentFile}"
    fi
    substituteVariables "appName" "${stubRunnerName}" "${serviceFile}"
    substituteVariables "env" "${LOWER_CASE_ENV}" "${serviceFile}"
    if [[ "${ENVIRONMENT}" == "TEST" ]]; then
        deleteAppByFile "${deploymentFile}"
        deleteAppByFile "${serviceFile}"
    fi
    replaceApp "${deploymentFile}"
    replaceApp "${serviceFile}"
    # TODO: FIX THIS :|
    echo "Waiting for the app to start"
    sleep ${DEFAULT_TIMEOUT}
}

function bindService() {
    local -r serviceName="${1}"
    local -r appName="${2}"
    echo "Binding service [${serviceName}] to app [${appName}]"
    cf bind-service "${appName}" "${serviceName}"
}

function createServiceWithName() {
    local -r name="${1}"
    echo "Creating service with name [${name}]"
    APPLICATION_DOMAIN=`cf apps | grep ${name} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
    JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
    cf create-user-provided-service "${name}" -p "${JSON}" || echo "Service already created. Proceeding with the script"
}

function prepareForSmokeTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    local -r appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    # TODO: Maybe this has to be changed somehow
    local -r applicationPort=$( portFromKubernetes "${appName}-${LOWER_CASE_ENV}" )
    local -r stubrunnerAppName="stubrunner-${appName}-${LOWER_CASE_ENV}"
    local -r stubrunnerPort=$( portFromKubernetes "${stubrunnerAppName}" )
    export kubHost=$( hostFromApi "${PAAS_TEST_API_URL}" )
    export APPLICATION_URL="${kubHost}:${applicationPort}"
    export STUBRUNNER_URL="${kubHost}:${stubrunnerPort}"
    echo "Application URL [${APPLICATION_URL}]"
    echo "StubRunner URL [${STUBRUNNER_URL}]"
}

function portFromKubernetes() {
    local -r appName="${1}"
    echo `kubectl get svc ${appName} -o jsonpath='{.spec.ports[0].nodePort}'`
}

function hostFromApi() {
    local -r api="${1}"
    local string
    IFS=':' read -r id string <<< "${api}"
    echo "$id"
}

function readTestPropertiesFromFile() {
    local -r fileLocation="${1:-${OUTPUT_FOLDER}/test.properties}"
    local key
    local value
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
    local -r projectGroupId=$( retrieveGroupId )
    local -r appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    deployServices

    # deploy app
    deployAndRestartAppWithNameForE2ETests "${appName}-${LOWER_CASE_ENV}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
    # TODO: FIX THIS :|
    echo "Waiting for the app to start"
    sleep ${DEFAULT_TIMEOUT}
}

function prepareForE2eTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    local -r appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    # TODO: Maybe this has to be changed somehow
    local -r applicationPort=$( portFromKubernetes "${appName}-${LOWER_CASE_ENV}" )
    local -r stubrunnerAppName="stubrunner-${appName}-${LOWER_CASE_ENV}"
    export kubHost=$( hostFromApi "${PAAS_TEST_API_URL}" )
    export APPLICATION_URL="${kubHost}:${applicationPort}"
    echo "Application URL [${APPLICATION_URL}]"
}

function performGreenDeployment() {
    # TODO: Consider making it less JVM specific
    local -r projectGroupId=$( retrieveGroupId )
    local -r appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    # TODO: Consider picking services and apps from file
    # services
    export UNIQUE_RABBIT_NAME="rabbitmq-${appName}-${LOWER_CASE_ENV}"
    deployService "RABBITMQ" "${UNIQUE_RABBIT_NAME}"
    export UNIQUE_MYSQL_NAME="mysql-${appName}-${LOWER_CASE_ENV}"
    deployService "MYSQL" "${UNIQUE_MYSQL_NAME}"

    # dependant apps
    export UNIQUE_EUREKA_NAME="eureka-${appName}-${LOWER_CASE_ENV}"
    deployService "EUREKA" "${UNIQUE_EUREKA_NAME}"
    # TODO: FIX THIS :|
    echo "Waiting for Eureka to start"
    sleep ${DEFAULT_TIMEOUT}

    # deploy app
    performGreenDeploymentOfTestedApplication "${appName}"
    # TODO: FIX THIS :|
    echo "Waiting for the app to start"
    sleep ${DEFAULT_TIMEOUT}
}

function performGreenDeploymentOfTestedApplication() {
    local -r appName="${1}"
    local -r newName="${appName}-venerable"
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
    local -r appName=$( retrieveAppName )
    # Log in to CF to start deployment
    logInToPaas
    local -r oldName="${appName}-venerable"
    local appPresent="no"
    echo "Deleting the app [${oldName}]"
    cf app "${oldName}" && appPresent="yes"
    if [[ "${appPresent}" == "yes" ]]; then
        cf delete "${oldName}" -f
    else
        echo "Will not remove the old application cause it's not there"
    fi
}

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOWER_CASE_ENV=$( lowerCaseEnv )

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
[[ -f "${__ROOT}/projectType/pipeline-jvm.sh" ]] && source "${__ROOT}/projectType/pipeline-jvm.sh" || \
    echo "No projectType/pipeline-jvm.sh found"

# TODO: MOve this back to pipeline-jvm
# OVerriding default building options

function build() {
    local -r appName=$( retrieveAppName )
    echo "Additional Build Options [${BUILD_OPTIONS}]"

    ./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${BUILD_OPTIONS}
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean package docker:build -DpushImageTags -DdockerImageTags="latest" -DdockerImageTags="${PIPELINE_VERSION}" ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
        ./mvnw docker:push ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
    else
        ./mvnw clean package docker:build -DpushImageTags -DdockerImageTags="latest" -DdockerImageTags="${PIPELINE_VERSION}" ${BUILD_OPTIONS}
        ./mvnw docker:push ${BUILD_OPTIONS}
    fi
}
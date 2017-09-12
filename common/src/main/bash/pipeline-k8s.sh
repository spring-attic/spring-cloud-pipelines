#!/bin/bash
set -e

function logInToPaas() {
    local redownloadInfra="${REDOWNLOAD_INFRA}"
    local ca="PAAS_${ENVIRONMENT}_CA"
    local k8sCa="${!ca}"
    local clientCert="PAAS_${ENVIRONMENT}_CLIENT_CERT"
    local k8sClientCert="${!clientCert}"
    local clientKey="PAAS_${ENVIRONMENT}_CLIENT_KEY"
    local k8sClientKey="${!clientKey}"
    local clusterName="PAAS_${ENVIRONMENT}_CLUSTER_NAME"
    local k8sClusterName="${!clusterName}"
    local clusterUser="PAAS_${ENVIRONMENT}_CLUSTER_USERNAME"
    local k8sClusterUser="${!clusterUser}"
    local systemName="PAAS_${ENVIRONMENT}_SYSTEM_NAME"
    local k8sSystemName="${!systemName}"
    export K8S_CONTEXT="${k8sSystemName}"
    local api="PAAS_${ENVIRONMENT}_API_URL"
    local apiUrl="${!api:-192.168.99.100:8443}"
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
    local projectGroupId=$( retrieveGroupId )
    local appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    deployServices

    # deploy app
    deployAndRestartAppWithNameForSmokeTests "${appName}" "${PIPELINE_VERSION}"
}

function testRollbackDeploy() {
    rm -rf ${OUTPUT_FOLDER}/test.properties
    local latestProdTag="${1}"
    local appName=$( retrieveAppName )
    LATEST_PROD_VERSION=${latestProdTag#prod/}
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    logInToPaas
    parsePipelineDescriptor

    deployAndRestartAppWithNameForSmokeTests "${appName}" "${LATEST_PROD_VERSION}"

    # Adding latest prod tag
    echo "LATEST_PROD_TAG=${latestProdTag}" >> ${OUTPUT_FOLDER}/test.properties
}

function deployService() {
    local serviceType=$( toLowerCase "${1}" )
    local serviceName="${2}"
    local serviceCoordinates=$( if [[ "${3}" == "null" ]] ; then echo ""; else echo "${3}" ; fi )
    local coordinatesSeparator=":"
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
      IFS=${coordinatesSeparator} read -r EUREKA_ARTIFACT_ID EUREKA_VERSION <<< "${serviceCoordinates}"
      IFS="${PREVIOUS_IFS}"
      deployEureka "${EUREKA_ARTIFACT_ID}:${EUREKA_VERSION}" "${serviceName}"
      ;;
    stubrunner)
      UNIQUE_EUREKA_NAME="$( eurekaName )"
      UNIQUE_RABBIT_NAME="$( rabbitMqName )"
      PREVIOUS_IFS="${IFS}"
      IFS=${coordinatesSeparator} read -r STUBRUNNER_ARTIFACT_ID STUBRUNNER_VERSION <<< "${serviceCoordinates}"
      IFS="${PREVIOUS_IFS}"
      PARSED_STUBRUNNER_USE_CLASSPATH="$( echo "${PARSED_YAML}" | jq --arg x "${LOWER_CASE_ENV}" '.[$x].services[] | select(.type == "stubrunner") | .useClasspath' | sed 's/^"\(.*\)"$/\1/' )"
      STUBRUNNER_USE_CLASSPATH=$( if [[ "${PARSED_STUBRUNNER_USE_CLASSPATH}" == "null" ]] ; then echo "false"; else echo "${PARSED_STUBRUNNER_USE_CLASSPATH}" ; fi )
      deployStubRunnerBoot "${STUBRUNNER_ARTIFACT_ID}:${STUBRUNNER_VERSION}" "${REPO_WITH_BINARIES}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${serviceName}"
      ;;
    *)
      echo "Unknown service [${serviceType}]"
      return 1
      ;;
    esac
}

function eurekaName() {
    echo "${PARSED_YAML}" | jq --arg x "${LOWER_CASE_ENV}" '.[$x].services[] | select(.type == "eureka") | .name' | sed 's/^"\(.*\)"$/\1/'
}

function rabbitMqName() {
    echo "${PARSED_YAML}" | jq --arg x "${LOWER_CASE_ENV}" '.[$x].services[] | select(.type == "rabbitmq") | .name' | sed 's/^"\(.*\)"$/\1/'
}

function mySqlName() {
    echo "${PARSED_YAML}" | jq --arg x "${LOWER_CASE_ENV}" '.[$x].services[] | select(.type == "mysql") | .name' | sed 's/^"\(.*\)"$/\1/'
}

function mySqlDatabase() {
    echo "${PARSED_YAML}" | jq --arg x "${LOWER_CASE_ENV}" '.[$x].services[] | select(.type == "mysql") | .database' | sed 's/^"\(.*\)"$/\1/'
}

function appSystemProps() {
    local systemProps=""
    # TODO: Not every system needs Eureka or Rabbit. But we need to bind this somehow...
    local eurekaName="$( eurekaName )"
    local rabbitMqName="$( rabbitMqName )"
    local mySqlName="$( mySqlName )"
    local mySqlDatabase="$( mySqlDatabase )"
    if [[ "${eurekaName}" != "" && "${eurekaName}" != "null" ]]; then
        systemProps="${systemProps} -Deureka.client.serviceUrl.defaultZone=http://${eurekaName}:8761/eureka"
    fi
    if [[ "${rabbitMqName}" != "" && "${rabbitMqName}" != "null" ]]; then
        systemProps="${systemProps} -DSPRING_RABBITMQ_ADDRESSES=${rabbitMqName}:5672"
    fi
    if [[ "${mySqlName}" != "" && "${mySqlName}" != "null" ]]; then
        systemProps="${systemProps} -Dspring.datasource.url=jdbc:mysql://${mySqlName}/${mySqlDatabase}"
    fi
    echo "${systemProps}"
}

function deleteService() {
    local serviceType="${1}"
    local serviceName="${2}"
    echo "Deleting all mysql related services with name [${serviceName}]"
    deleteAppByName ${serviceName}
}

function deployRabbitMq() {
    local serviceName="${1:-rabbitmq-github}"
    echo "Waiting for RabbitMQ to start"
    local foundApp=`kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" get pods -o wide -l app=${serviceName} | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        local originalDeploymentFile="${__ROOT}/k8s/rabbitmq.yml"
        local originalServiceFile="${__ROOT}/k8s/rabbitmq-service.yml"
        local outputDirectory="$( outputFolder )/k8s"
        rm -rf "${outputDirectory}"
        mkdir -p "${outputDirectory}"
        cp ${originalDeploymentFile} ${outputDirectory}
        cp ${originalServiceFile} ${outputDirectory}
        local deploymentFile="${outputDirectory}/rabbitmq.yml"
        local serviceFile="${outputDirectory}/rabbitmq-service.yml"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
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
    local fileName="${1}"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" create -f "${fileName}"
}

function replaceApp() {
    local fileName="${1}"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" replace --force -f "${fileName}"
}

function deleteAppByName() {
    local serviceName="${1}"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete secret "${serviceName}" || echo "Failed to delete secret [${serviceName}]. Continuing with the script"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete persistentvolumeclaim "${serviceName}"  || echo "Failed to delete persistentvolumeclaim [${serviceName}]. Continuing with the script"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete pod "${serviceName}" || echo "Failed to delete service [${serviceName}]. Continuing with the script"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete deployment "${serviceName}" || echo "Failed to delete deployment [${serviceName}] . Continuing with the script"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete service "${serviceName}" || echo "Failed to delete service [${serviceName}]. Continuing with the script"
}

function deleteAppByFile() {
    local file="${1}"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete -f ${file} || echo "Failed to delete app by [${file}] file. Continuing with the script"
}

function substituteVariables() {
    local variableName="${1}"
    local substitution="${2}"
    local fileName="${3}"
    local escapedSubstitution=$( escapeValueForSed "${substitution}" )
    #echo "Changing [${variableName}] -> [${escapedSubstitution}] for file [${fileName}]"
    sed -i "s/{{${variableName}}}/${escapedSubstitution}/" ${fileName}
}

function deleteMySql() {
    local serviceName="${1:-mysql-github}"
    echo "Deleting all mysql related services with name [${serviceName}]"
    deleteAppByName ${serviceName}
}

function deployMySql() {
    local serviceName="${1:-mysql-github}"
    local secretName
    secretName="mysql-$( retrieveAppName )"
    echo "Waiting for MySQL to start"
    local foundApp
    foundApp="$( findAppByName "${serviceName}" )"
    if [[ "${foundApp}" == "" ]]; then
        local originalDeploymentFile="${__ROOT}/k8s/mysql.yml"
        local originalServiceFile="${__ROOT}/k8s/mysql-service.yml"
        local outputDirectory="$( outputFolder )/k8s"
        rm -rf "${outputDirectory}"
        mkdir -p "${outputDirectory}"
        cp ${originalDeploymentFile} ${outputDirectory}
        cp ${originalServiceFile} ${outputDirectory}
        local deploymentFile="${outputDirectory}/mysql.yml"
        local serviceFile="${outputDirectory}/mysql-service.yml"
        local mySqlDatabase
        mySqlDatabase="$( mySqlDatabase )"
        echo "Generating secret with name [${secretName}]"
        kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete secret "${secretName}" || echo "Failed to delete secret [${serviceName}]. Continuing with the script"
        kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" create secret generic "${secretName}" --from-literal=username="${MYSQL_USER}" --from-literal=password="${MYSQL_PASSWORD}" --from-literal=rootpassword="${MYSQL_ROOT_PASSWORD}"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "secretName" "${secretName}" "${deploymentFile}"
        substituteVariables "mysqlDatabase" "${mySqlDatabase}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
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

function findAppByName() {
    local serviceName
    serviceName="${1}"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" get pods -o wide -l app="${serviceName}" | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'
}

function deployAndRestartAppWithName() {
    local appName="${1}"
    local jarName="${2}"
    local env="${LOWER_CASE_ENV}"
    echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}]"
    deployAppWithName "${appName}" "${jarName}" "${env}" 'true'
    restartApp "${appName}"
}

function deployAndRestartAppWithNameForSmokeTests() {
    local appName="${1}"
    local version="${2}"
    local profiles="smoke,kubernetes"
    local lowerCaseAppName=$( toLowerCase "${appName}" )
    local originalDeploymentFile="deployment.yml"
    local originalServiceFile="service.yml"
    local outputDirectory="$( outputFolder )/k8s"
    rm -rf "${outputDirectory}"
    mkdir -p "${outputDirectory}"
    cp ${originalDeploymentFile} ${outputDirectory}
    cp ${originalServiceFile} ${outputDirectory}
    local deploymentFile="${outputDirectory}/deployment.yml"
    local serviceFile="${outputDirectory}/service.yml"
    local systemProps="$( appSystemProps )"
    systemProps="-Dspring.profiles.active=${profiles} ${systemProps}"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "version" "${version}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "labelAppName" "${appName}" "${deploymentFile}"
    substituteVariables "containerName" "${appName}" "${deploymentFile}"
    substituteVariables "systemProps" "${systemProps}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    deleteAppByFile "${deploymentFile}"
    deleteAppByFile "${serviceFile}"
    deployApp "${deploymentFile}"
    deployApp "${serviceFile}"
    waitForAppToStart "${appName}"
}

function deployAndRestartAppWithNameForE2ETests() {
    local appName="${1}"
    local profiles="e2e,kubernetes"
    local lowerCaseAppName=$( toLowerCase "${appName}" )
    local originalDeploymentFile="deployment.yml"
    local originalServiceFile="service.yml"
    local outputDirectory="$( outputFolder )/k8s"
    rm -rf "${outputDirectory}"
    mkdir -p "${outputDirectory}"
    cp ${originalDeploymentFile} ${outputDirectory}
    cp ${originalServiceFile} ${outputDirectory}
    local deploymentFile="${outputDirectory}/deployment.yml"
    local serviceFile="${outputDirectory}/service.yml"
    local systemProps="-Dspring.profiles.active=${profiles}"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "version" "${PIPELINE_VERSION}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "labelAppName" "${appName}" "${deploymentFile}"
    substituteVariables "containerName" "${appName}" "${deploymentFile}"
    substituteVariables "systemProps" "${systemProps}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    deleteAppByFile "${deploymentFile}"
    deleteAppByFile "${serviceFile}"
    deployApp "${deploymentFile}"
    deployApp "${serviceFile}"
    waitForAppToStart "${appName}"
}

function toLowerCase() {
    local string=${1}
    echo "${string}" | tr '[:upper:]' '[:lower:]'
}

function lowerCaseEnv() {
    echo "${ENVIRONMENT}" | tr '[:upper:]' '[:lower:]'
}

function deleteAppInstance() {
    local serviceName="${1}"
    local lowerCaseAppName=$( toLowerCase "${serviceName}" )
    echo "Deleting application [${lowerCaseAppName}]"
    deleteAppByName "${lowerCaseAppName}"
}

function deployEureka() {
    local imageName="${1}"
    local appName="${2}"
    echo "Deploying Eureka. Options - image name [${imageName}], app name [${appName}], env [${ENVIRONMENT}]"
    local originalDeploymentFile="${__ROOT}/k8s/eureka.yml"
    local originalServiceFile="${__ROOT}/k8s/eureka-service.yml"
    local outputDirectory="$( outputFolder )/k8s"
    rm -rf "${outputDirectory}"
    mkdir -p "${outputDirectory}"
    cp ${originalDeploymentFile} ${outputDirectory}
    cp ${originalServiceFile} ${outputDirectory}
    local deploymentFile="${outputDirectory}/eureka.yml"
    local serviceFile="${outputDirectory}/eureka-service.yml"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "appUrl" "${appName}.${PAAS_NAMESPACE}" "${deploymentFile}"
    substituteVariables "eurekaImg" "${imageName}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    if [[ "${ENVIRONMENT}" == "TEST" ]]; then
        deleteAppByFile "${deploymentFile}"
        deleteAppByFile "${serviceFile}"
    fi
    replaceApp "${deploymentFile}"
    replaceApp "${serviceFile}"
    waitForAppToStart "${appName}"
}

function escapeValueForSed() {
    echo "${1//\//\\/}"
}

function deployStubRunnerBoot() {
    local imageName="${1}"
    local repoWithJars="${2}"
    local rabbitName="${3}.${PAAS_NAMESPACE}"
    local eurekaName="${4}.${PAAS_NAMESPACE}"
    local stubRunnerName="${5:-stubrunner}"
    local fileExists="true"
    local stubRunnerUseClasspath="${STUBRUNNER_USE_CLASSPATH:-false}"
    echo "Deploying Stub Runner. Options - image name [${imageName}], app name [${stubRunnerName}]"
    local prop="$( retrieveStubRunnerIds )"
    echo "Found following stub runner ids [${prop}]"
    local originalDeploymentFile="${__ROOT}/k8s/stubrunner.yml"
    local originalServiceFile="${__ROOT}/k8s/stubrunner-service.yml"
    local outputDirectory="$( outputFolder )/k8s"
    rm -rf "${outputDirectory}"
    mkdir -p "${outputDirectory}"
    cp ${originalDeploymentFile} ${outputDirectory}
    cp ${originalServiceFile} ${outputDirectory}
    local deploymentFile="${outputDirectory}/stubrunner.yml"
    local serviceFile="${outputDirectory}/stubrunner-service.yml"
    if [[ "${stubRunnerUseClasspath}" == "false" ]]; then
        substituteVariables "repoWithJars" "${repoWithJars}" "${deploymentFile}"
    else
        substituteVariables "repoWithJars" "" "${deploymentFile}"
    fi
    substituteVariables "appName" "${stubRunnerName}" "${deploymentFile}"
    substituteVariables "stubrunnerImg" "${imageName}" "${deploymentFile}"
    substituteVariables "rabbitAppName" "${rabbitName}" "${deploymentFile}"
    substituteVariables "eurekaAppName" "${eurekaName}" "${deploymentFile}"
    if [[ "${prop}" == "false" ]]; then
        substituteVariables "stubrunnerIds" "${prop}" "${deploymentFile}"
    else
        substituteVariables "stubrunnerIds" "" "${deploymentFile}"
    fi
    substituteVariables "appName" "${stubRunnerName}" "${serviceFile}"
    if [[ "${ENVIRONMENT}" == "TEST" ]]; then
        deleteAppByFile "${deploymentFile}"
        deleteAppByFile "${serviceFile}"
    fi
    replaceApp "${deploymentFile}"
    replaceApp "${serviceFile}"
    waitForAppToStart "${stubRunnerName}"
}

function prepareForSmokeTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    local appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    # TODO: Maybe this has to be changed somehow
    local applicationPort=$( portFromKubernetes "${appName}" )
    local stubrunnerAppName="stubrunner-${appName}"
    local stubrunnerPort=$( portFromKubernetes "${stubrunnerAppName}" )
    export kubHost=$( hostFromApi "${PAAS_TEST_API_URL}" )
    export APPLICATION_URL="${kubHost}:${applicationPort}"
    export STUBRUNNER_URL="${kubHost}:${stubrunnerPort}"
    echo "Application URL [${APPLICATION_URL}]"
    echo "StubRunner URL [${STUBRUNNER_URL}]"
}

function portFromKubernetes() {
    local appName="${1}"
    echo `kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" get svc ${appName} -o jsonpath='{.spec.ports[0].nodePort}'`
}

function waitForAppToStart() {
    local appName="${1}"
    local apiUrlVar="PAAS_${ENVIRONMENT}_API_URL"
    local apiUrl="${!apiUrlVar}"
    local port=$( portFromKubernetes "${appName}" )
    local kubHost=$( hostFromApi "${apiUrl}" )
    isAppRunning "${kubHost}" "${port}"
}

function retrieveApplicationUrl() {
    local appName=$( retrieveAppName )
    local apiUrlVar="PAAS_${ENVIRONMENT}_API_URL"
    local apiUrl="${!apiUrlVar}"
    local port=$( portFromKubernetes "${appName}" )
    local kubHost=$( hostFromApi "${apiUrl}" )
    echo "${kubHost}:${port}"
}

function isAppRunning() {
    local host="${1}"
    local port="${2}"
    local waitTime=5
    local retries=50
    local running=1
    local healthEndpoint="health"
    for i in $( seq 1 "${retries}" ); do
        sleep "${waitTime}"
        curl -m 5 "${host}:${port}/${healthEndpoint}" && running=0 && break
        echo "Fail #$i/${retries}... will try again in [${waitTime}] seconds"
    done
    if [[ "${running}" == 1 ]]; then
        echo "App failed to start"
        exit 1
    fi
    echo -e "\nApp started successfully!"
}

function hostFromApi() {
    local api="${1}"
    local string
    local id
    IFS=':' read -r id string <<< "${api}"
    echo "$id"
}

function readTestPropertiesFromFile() {
    local fileLocation="${1:-${OUTPUT_FOLDER}/test.properties}"
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

function label() {
    local appName="${1}"
    local key="${2}"
    local value="${3}"
    local type="deployment"
    kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" label "${type}" "${appName}" "${key}"="${value}"
}

function objectDeployed() {
    local appType="${1}"
    local appName="${2}"
    local result=$( kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" get "${appType}" "${appName}" --ignore-not-found=true )
    if [[ "${result}" != "" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

function stageDeploy() {
    # TODO: Consider making it less JVM specific
    local projectGroupId=$( retrieveGroupId )
    local appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    deployServices

    # deploy app
    deployAndRestartAppWithNameForE2ETests "${appName}"
}

function prepareForE2eTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    local appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    local applicationPort=$( portFromKubernetes "${appName}" )
    export kubHost=$( hostFromApi "${PAAS_STAGE_API_URL}" )
    export APPLICATION_URL="${kubHost}:${applicationPort}"
    echo "Application URL [${APPLICATION_URL}]"
}

function performGreenDeployment() {
    # TODO: Consider making it less JVM specific
    local appName=$( retrieveAppName )
    # Log in to PaaS to start deployment
    logInToPaas

    # deploy app
    performGreenDeploymentOfTestedApplication "${appName}"
}

function performGreenDeploymentOfTestedApplication() {
    local appName="${1}"
    local lowerCaseAppName=$( toLowerCase "${appName}" )
    local profiles="kubernetes"
    local originalDeploymentFile="deployment.yml"
    local originalServiceFile="service.yml"
    local outputDirectory="$( outputFolder )/k8s"
    rm -rf "${outputDirectory}"
    mkdir -p "${outputDirectory}"
    cp ${originalDeploymentFile} ${outputDirectory}
    cp ${originalServiceFile} ${outputDirectory}
    local deploymentFile="${outputDirectory}/deployment.yml"
    local serviceFile="${outputDirectory}/service.yml"
    local changedAppName="$( escapeValueForDns ${appName}-${PIPELINE_VERSION} )"
    echo "Will name the application [${changedAppName}]"
    local systemProps="-Dspring.profiles.active=${profiles}"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "version" "${PIPELINE_VERSION}" "${deploymentFile}"
    # The name will contain also the version
    substituteVariables "labelAppName" "${changedAppName}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${deploymentFile}"
    substituteVariables "containerName" "${appName}" "${deploymentFile}"
    substituteVariables "systemProps" "${systemProps}" "${deploymentFile}"
    substituteVariables "appName" "${appName}" "${serviceFile}"
    deployApp "${deploymentFile}"
    local serviceDeployed="$( objectDeployed "service" ${appName} )"
    echo "Service already deployed? [${serviceDeployed}]"
    if [[ "${serviceDeployed}" == "false" ]]; then
        deployApp "${serviceFile}"
    fi
    waitForAppToStart "${appName}"
}

function escapeValueForDns() {
    local sed="$(sed -e 's/\./-/g;s/_/-/g' <<< "$1")"
    local lowerCaseSed="$( toLowerCase ${sed} )"
    echo "${lowerCaseSed}"
}

function deleteBlueInstance() {
    local appName=$( retrieveAppName )
    # Log in to CF to start deployment
    logInToPaas
    # find the oldest version and remove it
    local oldestDeployment="$( oldestDeployment "${appName}" )"
    if [[ "${oldestDeployment}" != "" ]]; then
        echo "Deleting deployment with name [${oldestDeployment}]"
        kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" delete deployment "${oldestDeployment}"
    else
        echo "There's no blue instance to remove, skipping this step"
    fi
}

function oldestDeployment() {
    local appName="${1}"
    local changedAppName="$( escapeValueForDns ${appName}-${PIPELINE_VERSION} )"
    local deployedApps="$( kubectl --context="${K8S_CONTEXT}" --namespace="${PAAS_NAMESPACE}" get deployments -lname="${appName}" --no-headers | awk '{print $1}' | grep -v "${changedAppName}" )"
    local oldestDeployment="$( echo "${deployedApps}" | sort | head -n 1 )"
    echo "${oldestDeployment}"
}

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LOWER_CASE_ENV=$( lowerCaseEnv )
export PAAS_NAMESPACE_VAR="PAAS_${ENVIRONMENT}_NAMESPACE"
[[ -z "${PAAS_NAMESPACE}" ]] && PAAS_NAMESPACE="${!PAAS_NAMESPACE_VAR}"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
[[ -f "${__ROOT}/projectType/pipeline-jvm.sh" ]] && source "${__ROOT}/projectType/pipeline-jvm.sh" || \
    echo "No projectType/pipeline-jvm.sh found"

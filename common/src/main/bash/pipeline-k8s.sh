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
    local api="PAAS_${ENVIRONMENT}_API_URL"
    local apiUrl="${!api:-192.168.99.100:8443}"
    CLI_INSTALLED="$( kubectl version || echo "false" )"
    CLI_DOWNLOADED="$( test -r kubectl && echo "true" || echo "false" )"
    echo "CLI Installed? [${CLI_INSTALLED}], CLI Downloaded? [${CLI_DOWNLOADED}]"
    if [[ ${CLI_INSTALLED} == "false" && (${CLI_DOWNLOADED} == "false" || ${CLI_DOWNLOADED} == "true" && ${redownloadInfra} == "true") ]]; then
        echo "Downloading CLI"
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl --fail
        CLI_DOWNLOADED="true"
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
    deployAndRestartAppWithNameForSmokeTests ${appName} "${appName}-${PIPELINE_VERSION}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
}

function testRollbackDeploy() {
    rm -rf ${OUTPUT_FOLDER}/test.properties
    local latestProdTag="${1}"
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )
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
      deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${serviceName}" "${ENVIRONMENT}"
      ;;
    STUBRUNNER)
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
    local foundApp=`kubectl get pods -o wide -l app=${serviceName} | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        local deploymentFile="${__ROOT}/k8s/rabbitmq.yml"
        local serviceFile="${__ROOT}/k8s/rabbitmq-service.yml"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "env" "${ENVIRONMENT}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
        substituteVariables "env" "${ENVIRONMENT}" "${serviceFile}"
        #echo "Printing substituted file contents"
        #echo "Deployment"
        #cat ${deploymentFile}
        #echo "Service"
        #cat ${serviceFile}
        deployApp "${deploymentFile}"
        deployApp "${serviceFile}"
    else
        echo "Service [${serviceName}] already started"
    fi
}

function deployApp() {
    local fileName="${1}"
    kubectl create -f "${fileName}"
}

function deleteAppByName() {
    local serviceName="${1}"
    kubectl delete service ${serviceName} -l environment="${ENVIRONMENT}" || echo "Failed to delete service [${serviceName}] for env [${ENVIRONMENT}]. Continuing with the script"
    kubectl delete deployment ${serviceName} -l environment="${ENVIRONMENT}" || echo "Failed to delete service [${serviceName}] for env [${ENVIRONMENT}]. Continuing with the script"
}

function deleteAppByFile() {
    local file="${1}"
    kubectl delete -f ${file} || echo "Failed to delete ${file}. Continuing with the script"
}

function substituteVariables() {
    local variableName="${1}"
    local substitution="${2}"
    local fileName="${3}"
    #echo "Changing [${variableName}] -> [${substitution}] for file [${fileName}]"
    sed -i "s/{{${variableName}}}/${substitution}/" ${fileName}
}

function deleteMySql() {
    local serviceName="${1:-mysql-github}"
    deleteAppByName ${serviceName}
}

function deployMySql() {
    local serviceName="${1:-mysql-github}"
    echo "Waiting for MySQL to start"
    local foundApp=`kubectl get pods -o wide -l app=${serviceName} | awk -v "app=${serviceName}" '$1 ~ app {print($0)}'`
    if [[ "${foundApp}" == "" ]]; then
        local deploymentFile="${__ROOT}/k8s/mysql.yml"
        local serviceFile="${__ROOT}/k8s/mysql-service.yml"
        echo "Generating secret"
        kubectl create secret generic "${appName}-secret" --from-literal=username="${MYSQL_USER}" --from-literal=password="${MYSQL_PASSWORD}" --from-literal=rootpassword="${MYSQL_ROOT_PASSWORD}"
        substituteVariables "appName" "${serviceName}" "${deploymentFile}"
        substituteVariables "env" "${ENVIRONMENT}" "${deploymentFile}"
        substituteVariables "mysqlDatabase" "${MYSQL_DATABASE}" "${deploymentFile}"
        substituteVariables "appName" "${serviceName}" "${serviceFile}"
        substituteVariables "env" "${ENVIRONMENT}" "${serviceFile}"
        deployApp "${deploymentFile}"
        deployApp "${serviceFile}"
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
    local deploymentFile="deployment.yml"
    local serviceFile="service.yml"
    deleteAppByFile "${deploymentFile}"
    deleteAppByFile "${serviceFile}"
    local systemOpts="-Dspring.profiles.active=${profiles}"
    systemOpts="${systemOpts} -DSPRING_RABBITMQ_ADDRESSES=${rabbitName} -Deureka_client_serviceUrl_defaultZone=${eurekaAppName}"
    substituteVariables "dockerOrg" "${DOCKER_REGISTRY_ORGANIZATION}" "${deploymentFile}"
    substituteVariables "appName" "${serviceName}" "${deploymentFile}"
    substituteVariables "env" "${ENVIRONMENT}" "${deploymentFile}"
    substituteVariables "appName" "${serviceName}" "${serviceFile}"
    substituteVariables "env" "${ENVIRONMENT}" "${serviceFile}"
    deployApp "${deploymentFile}"
    deployApp "${serviceFile}"
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
    kubectl delete deployment ${APP_NAME}-deployment || echo "Failed to delete app deployment. Continuing with the script"
    kubectl delete service ${APP_NAME}-service || echo "Failed to delete app service. Continuing with the script"
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
    local imageName="${2}"
    local appName="${3}"
    local env="${4}"
    echo "Deploying Eureka. Options - redeploy [${redeploy}], jar name [${imageName}], app name [${appName}], env [${env}]"
    if [[ "${redeploy}" == "true" ]]; then
        local deploymentFile="${__ROOT}/k8s/eureka.yml"
        local serviceFile="${__ROOT}/k8s/eureka-service.yml"
        substituteVariables "appName" "${appName}" "${deploymentFile}"
        substituteVariables "env" "${env}" "${deploymentFile}"
        substituteVariables "eurekaImg" "${imageName}" "${deploymentFile}"
        substituteVariables "appName" "${appName}" "${serviceFile}"
        substituteVariables "env" "${env}" "${serviceFile}"
        deployApp "${deploymentFile}"
        deployApp "${appName}"
    else
        echo "Current folder is [`pwd`]; Redeploy flag was set [${redeploy}]. Skipping deployment"
    fi
}

function deployStubRunnerBoot() {
    local redeploy="${1}"
    local imageName="${2}"
    # TODO: Add passing of properties to docker images
    local repoWithJars="${3}"
    local rabbitName="${4}"
    local eurekaName="${5}"
    local env="${6:-test}"
    local stubRunnerName="${7:-stubrunner}"
    local fileExists="true"
    local stubRunnerUseClasspath="${STUBRUNNER_USE_CLASSPATH:-false}"
    echo "Deploying Stub Runner. Options - redeploy [${redeploy}], jar name [${imageName}], app name [${stubRunnerName}]"
    if [[ ${redeploy} == "true" ]]; then
        local prop="$( retrieveStubRunnerIds )"
        echo "Found following stub runner ids [${prop}]"
        local systemOpts=""
        if [[ "${stubRunnerUseClasspath}" == "false" ]]; then
            systemOpts="${systemOpts} -Dstubrunner.repositoryRoot=${repoWithJars}"
        fi
        systemOpts="${systemOpts} -DSPRING_RABBITMQ_ADDRESSES=${rabbitName} -Deureka_client_serviceUrl_defaultZone=${eurekaAppName}"
        local deploymentFile="${__ROOT}/k8s/stubrunner.yml"
        local serviceFile="${__ROOT}/k8s/stubrunner-service.yml"
        substituteVariables "appName" "${appName}" "${deploymentFile}"
        substituteVariables "env" "${env}" "${deploymentFile}"
        substituteVariables "systemOpts" "${systemOpts}" "${deploymentFile}"
        substituteVariables "stubrunnerIds" "${prop}" "${deploymentFile}"
        substituteVariables "appName" "${appName}" "${serviceFile}"
        substituteVariables "env" "${env}" "${serviceFile}"
        deployApp "${deploymentFile}"
        deployApp "${appName}"
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

function prepareForSmokeTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    appName=$( retrieveAppName )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
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

    downloadAppArtifact 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${PIPELINE_VERSION}

    # deploy app
    deployAndRestartAppWithName ${appName} "${appName}-${PIPELINE_VERSION}"
}

function prepareForE2eTests() {
    echo "Retrieving group and artifact id - it can take a while..."
    appName=$( retrieveAppName )
    echo "Project artifactId is ${appName}"
    mkdir -p "${OUTPUT_FOLDER}"
    logInToPaas
    echo "Application URL [${APPLICATION_URL}]"
}

function performGreenDeployment() {
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )

    # download app
    downloadAppArtifact 'true' ${REPO_WITH_BINARIES} ${projectGroupId} ${appName} ${PIPELINE_VERSION}
    # Log in to CF to start deployment
    logInToPaas

    # deploying infra
    # TODO: most likely rabbitmq / eureka / db would be there on production; this remains for demo purposes
    deployRabbitMq
    deployMySql "mysql-github-analytics"
    downloadAppArtifact ${REDEPLOY_INFRA} ${REPO_WITH_BINARIES} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
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

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CURRENTLY WE ONLY SUPPORT JVM BASED PROJECTS OUT OF THE BOX
[[ -f "${__ROOT}/projectType/pipeline-jvm.sh" ]] && source "${__ROOT}/projectType/pipeline-jvm.sh" || \
    echo "No projectType/pipeline-jvm.sh found"
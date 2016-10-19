#!/bin/bash

set -e

# It takes ages on Docker to run the app without this
export MAVEN_OPTS="${MAVEN_OPTS} -Djava.security.egd=file:///dev/urandom"

function logInToCf() {
    local redownloadInfra="${1}"
    local cfUsername="${2}"
    local cfPassword="${3}"
    local cfOrg="${4}"
    local cfSpace="${5}"
    local apiUrl="${6:-api.run.pivotal.io}"
    CF_INSTALLED="$( cf --version || echo "false" )"
    CF_DOWNLOADED="$( test -r cf && echo "true" || echo "false" )"
    echo "CF Installed? [${CF_INSTALLED}], CF Downloaded? [${CF_DOWNLOADED}]"
    if [[ ${CF_INSTALLED} == "false" && (${CF_DOWNLOADED} == "false" || ${CF_DOWNLOADED} == "true" && ${redownloadInfra} == "true") ]]; then
        echo "Downloading Cloud Foundry"
        curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
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
    set +x
    cf login -u "${cfUsername}" -p "${cfPassword}" -o "${cfOrg}" -s "${cfSpace}"
}

function deployRabbitMqToCf() {
    local rabbitMqAppName="${1:-github-rabbitmq}"
    echo "Waiting for RabbitMQ to start"
    # create RabbitMQ
    APP_NAME="${rabbitMqAppName}"
    (cf s | grep "${APP_NAME}" && echo "found ${APP_NAME}") ||
        (cf cs cloudamqp lemur "${APP_NAME}" && echo "Started RabbitMQ") ||
        (cf cs p-rabbitmq standard "${APP_NAME}" && echo "Started RabbitMQ for PCF Dev")
}

function deployAndRestartAppWithName() {
    local appName="${1}"
    local jarName="${2}"
    local env="${3}"
    echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}]"
    deployAppWithName "${appName}" "${jarName}" "${env}" 'true'
    restartApp "${appName}"
}

function deployAndRestartAppWithNameForSmokeTests() {
    local appName="${1}"
    local jarName="${2}"
    local env="${3:-test}"
    local lowerCaseAppName=$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )
    echo "Deploying and restarting app with name [${appName}] and jar name [${jarName}] and env [${env}]"
    deployAppWithName "${appName}" "${jarName}" "${env}" 'true'
    setEnvVar "${lowerCaseAppName}" 'spring.profiles.active' "cloud,smoke"
    restartApp "${appName}"
}

function appHost() {
    local appName="${1}"
    local lowerCase="$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )"
    APP_HOST=`cf apps | grep ${lowerCase} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
    echo "${APP_HOST}"
}

function deployAppWithName() {
    local appName="${1}"
    local jarName="${2}"
    local env="${3}"
    local useManifest="${4:-false}"
    local manifestOption=$( if [[ "${useManifest}" == "false" ]] ; then echo "--no-manifest"; else echo "" ; fi )
    local lowerCaseAppName=$( echo "${appName}" | tr '[:upper:]' '[:lower:]' )
    local hostname="${lowerCaseAppName}"
    if [[ ${env} != "prod" ]]; then
        hostname="${hostname}-${env}"
    fi
    echo "Deploying app with name [${lowerCaseAppName}], env [${env}] with manifest [${useManifest}] and host [${hostname}]"
    if [[ ! -z "${manifestOption}" ]]; then
        cf push "${lowerCaseAppName}" -m 1024m -i 1 -p "${OUTPUT_FOLDER}/${jarName}.jar" -n "${hostname}" --no-start -b https://github.com/cloudfoundry/java-buildpack.git#v3.8.1 ${manifestOption}
    else
        cf push "${lowerCaseAppName}" -p "${OUTPUT_FOLDER}/${jarName}.jar" -n "${hostname}" --no-start -b https://github.com/cloudfoundry/java-buildpack.git#v3.8.1
    fi
    APPLICATION_DOMAIN="$( appHost ${lowerCaseAppName} )"
    echo "Determined that application_domain for [${lowerCaseAppName}] is [${APPLICATION_DOMAIN}]"
    setEnvVar "${lowerCaseAppName}" 'APPLICATION_DOMAIN' "${APPLICATION_DOMAIN}"
    setEnvVar "${lowerCaseAppName}" 'JAVA_OPTS' '-Djava.security.egd=file:///dev/urandom'
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
    local env="${3:-test}"
    local stubRunnerName="${4:-stubrunner}"
    local fileExists="true"
    local fileName="`pwd`/${OUTPUT_FOLDER}/${jarName}.jar"
    if [[ ! -f "${fileName}" ]]; then
        fileExists="false"
    fi
    echo "Deploying Stub Runner. Options - redeploy [${redeploy}], jar name [${jarName}], app name [${stubRunnerName}]"
    if [[ ${fileExists} == "false" || ( ${fileExists} == "true" && ${redeploy} == "true" ) ]]; then
        deployAppWithName "${stubRunnerName}" "${jarName}" "${env}"
        local prop="$( retrieveStubRunnerIds )"
        setEnvVar "${stubRunnerName}" "stubrunner.ids" "${prop}"
        restartApp "${stubRunnerName}"
        createServiceWithName "${stubRunnerName}"
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

# The function uses Maven Wrapper - if you're using Maven you have to have it on your classpath
# and change this function
function extractMavenProperty() {
    local prop="${1}"
    MAVEN_PROPERTY=$(./mvnw ${MAVEN_ARGS} -q \
                    -Dexec.executable="echo" \
                    -Dexec.args="\${${prop}}" \
                    --non-recursive \
                    org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
    # In some spring cloud projects there is info about deactivating some stuff
    MAVEN_PROPERTY=$( echo "${MAVEN_PROPERTY}" | tail -1 )
    echo "${MAVEN_PROPERTY}"
}

# The values of group / artifact ids can be later retrieved from Maven
function downloadJar() {
    local redownloadInfra="${1}"
    local repoWithJars="${2}"
    local groupId="${3}"
    local artifactId="${4}"
    local version="${5}"
    local destination="`pwd`/${OUTPUT_FOLDER}/${artifactId}-${version}.jar"
    local changedGroupId="$( echo "${groupId}" | tr . / )"
    local pathToJar="${repoWithJars}/${changedGroupId}/${artifactId}/${version}/${artifactId}-${version}.jar"
    if [[ ! -e ${destination} || ( -e ${destination} && ${redownloadInfra} == "true" ) ]]; then
        mkdir -p "${OUTPUT_FOLDER}"
        echo "Current folder is [`pwd`]; Downloading [${pathToJar}] to [${destination}]"
        curl "${pathToJar}" -o "${destination}"
    else
        echo "File [${destination}] exists and redownload flag was set to false. Will not download it again"
    fi
}

function propagatePropertiesForTests() {
    local projectArtifactId="${1}"
    local stubRunnerHost="${2:-stubrunner}"
    local fileLocation="${3:-${OUTPUT_FOLDER}/test.properties}"
    # retrieve host of the app / stubrunner
    # we have to store them in a file that will be picked as properties
    rm -rf "${fileLocation}"
    local host=$( appHost "${projectArtifactId}" )
    APPLICATION_URL="${host}"
    echo "APPLICATION_URL=${host}" >> ${fileLocation}
    host=$( appHost "${stubRunnerHost}" )
    STUBRUNNER_URL="${host}"
    echo "STUBRUNNER_URL=${host}" >> ${fileLocation}
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

# Function that executes integration tests
function runSmokeTests() {
    local applicationHost="${1}"
    local stubrunnerHost="${2}"
    echo "Running smoke tests"

    if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
        if [[ ! -z ${MAVEN_ARGS} ]]; then
            ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" "${MAVEN_ARGS}"
        else
            ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}"
        fi
    elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        ./gradlew smoke -PnewVersion=${PIPELINE_VERSION} -DM2_LOCAL="${M2_LOCAL}" -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}"
    else
        echo "Unsupported project build tool"
        return 1
    fi
}

# Function that executes end to end tests
function runE2eTests() {
    local applicationHost="${1}"
    local stubrunnerHost="${2}"
    echo "Running e2e tests"

    if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
        if [[ ! -z ${MAVEN_ARGS} ]]; then
            ./mvnw clean install -Pe2e -Dapplication.url="${applicationHost}" "${MAVEN_ARGS}"
        else
            ./mvnw clean install -Pe2e -Dapplication.url="${applicationHost}"
        fi
    elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        ./gradlew e2e -PnewVersion=${PIPELINE_VERSION} -DM2_LOCAL="${M2_LOCAL}" -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}"
    else
        echo "Unsupported project build tool"
        return 1
    fi
}

function findLatestProdTag() {
    local LAST_PROD_TAG=$(git for-each-ref --sort=taggerdate --format '%(refname)' refs/tags/prod | head -n 1)
    LAST_PROD_TAG=${LAST_PROD_TAG#refs/tags/}
    echo "${LAST_PROD_TAG}"
}

function extractVersionFromProdTag() {
    local tag="${1}"
    LAST_PROD_VERSION=${tag#prod/}
    echo "${LAST_PROD_VERSION}"
}

function retrieveGroupId() {
    if [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        local result=$( ./gradlew groupId -q )
        result=$( echo "${result}" | tail -1 )
        echo "${result}"
    else
        local result=$( ruby -r rexml/document -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/groupId"].text' pom.xml || ./mvnw ${MAVEN_ARGS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate -Dexpression=project.groupId |grep -Ev '(^\[|Download\w+:)' )
        result=$( echo "${result}" | tail -1 )
        echo "${result}"
    fi
}

function retrieveArtifactId() {
    if [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        local result=$( ./gradlew artifactId -q )
        result=$( echo "${result}" | tail -1 )
        echo "${result}"
    else
        local result=$( ruby -r rexml/document -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/artifactId"].text' pom.xml || ./mvnw ${MAVEN_ARGS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate -Dexpression=project.artifactId |grep -Ev '(^\[|Download\w+:)' )
        result=$( echo "${result}" | tail -1 )
        echo "${result}"
    fi
}

# Jenkins passes these as a separate step, in Concourse we'll do it manually
function prepareForSmokeTests() {
    local redownloadInfra="${1}"
    local username="${2}"
    local password="${3}"
    local org="${4}"
    local space="${5}"
    local api="${6}"
    echo "Retrieving group and artifact id - it can take a while..."
    projectGroupId=$( retrieveGroupId )
    projectArtifactId=$( retrieveArtifactId )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToCf "${redownloadInfra}" "${username}" "${password}" "${org}" "${space}" "${api}"
    propagatePropertiesForTests ${projectArtifactId}
    readTestPropertiesFromFile
}

# Jenkins passes these as a separate step, in Concourse we'll do it manually
function prepareForE2eTests() {
    local redownloadInfra="${1}"
    local username="${2}"
    local password="${3}"
    local org="${4}"
    local space="${5}"
    local api="${6}"
    echo "Retrieving group and artifact id - it can take a while..."
    projectGroupId=$( retrieveGroupId )
    projectArtifactId=$( retrieveArtifactId )
    mkdir -p "${OUTPUT_FOLDER}"
    logInToCf "${redownloadInfra}" "${username}" "${password}" "${org}" "${space}" "${api}"
    propagatePropertiesForTests ${projectArtifactId}
    readTestPropertiesFromFile
}

function isMavenProject() {
    if [ -f "mvnw" ];
    then
       return 0
    else
       return 1
    fi
}

function isGradleProject() {
    if [ -f "gradlew" ];
    then
       return 0
    else
       return 1
    fi
}

function projectType() {
    (isMavenProject && PROJECT_TYPE="MAVEN") || (isGradleProject && PROJECT_TYPE="GRADLE") || PROJECT_TYPE="UNKNOWN"
    echo "${PROJECT_TYPE}"
}

function outputFolder() {
    if [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        echo "build/libs"
    else
        echo "target"
    fi
}

function testResultsFolder() {
    if [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        echo "**/test-results/**/*.xml"
    else
        echo "**/surefire-reports/*.xml"
    fi
}

function retrieveStubRunnerIds() {
    if [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        echo "$( ./gradlew stubIds -q )"
    else
        echo "$( extractMavenProperty 'stubrunner.ids' )"
    fi
}

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )
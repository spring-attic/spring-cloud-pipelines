#!/bin/bash
set -e

# It takes ages on Docker to run the app without this
if [[ ${BUILD_OPTIONS} != *"java.security.egd"* ]]; then
    if [[ ! -z ${BUILD_OPTIONS} && ${BUILD_OPTIONS} != "null" ]]; then
        export BUILD_OPTIONS="${BUILD_OPTIONS} -Djava.security.egd=file:///dev/urandom"
    else
        export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
    fi
fi


function build() {
    echo "Additional Build Options [${BUILD_OPTIONS}]"

    ./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${BUILD_OPTIONS}
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_BINARIES} -Drepo.with.binaries=${REPO_WITH_BINARIES} ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
    else
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_BINARIES} -Drepo.with.binaries=${REPO_WITH_BINARIES} ${BUILD_OPTIONS}
    fi
}

function apiCompatibilityCheck() {
    echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."
    projectGroupId=$( retrieveGroupId )
    appName=$( retrieveAppName )

    # Find latest prod version
    LATEST_PROD_TAG=$( findLatestProdTag )
    echo "Last prod tag equals ${LATEST_PROD_TAG}"
    if [[ -z "${LATEST_PROD_TAG}" ]]; then
        echo "No prod release took place - skipping this step"
    else
        # Downloading latest jar
        LATEST_PROD_VERSION=${LATEST_PROD_TAG#prod/}
        echo "Last prod version equals ${LATEST_PROD_VERSION}"
        echo "Additional Build Options [${BUILD_OPTIONS}]"
        if [[ "${CI}" == "CONCOURSE" ]]; then
            ./mvnw clean verify -Papicompatibility -Dlatest.production.version=${LATEST_PROD_VERSION} -Drepo.with.binaries=${REPO_WITH_BINARIES} ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
        else
            ./mvnw clean verify -Papicompatibility -Dlatest.production.version=${LATEST_PROD_VERSION} -Drepo.with.binaries=${REPO_WITH_BINARIES} ${BUILD_OPTIONS}
        fi
    fi
}

# The function uses Maven Wrapper - if you're using Maven you have to have it on your classpath
# and change this function
function extractMavenProperty() {
    local prop="${1}"
    MAVEN_PROPERTY=$(./mvnw ${BUILD_OPTIONS} -q \
                    -Dexec.executable="echo" \
                    -Dexec.args="\${${prop}}" \
                    --non-recursive \
                    org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
    # In some spring cloud projects there is info about deactivating some stuff
    MAVEN_PROPERTY=$( echo "${MAVEN_PROPERTY}" | tail -1 )
    # In Maven if there is no property it prints out ${propname}
    if [[ "${MAVEN_PROPERTY}" == "\${${prop}}" ]]; then
        echo ""
    else
        echo "${MAVEN_PROPERTY}"
    fi
}

function retrieveGroupId() {
    local result=$( ruby -r rexml/document -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/groupId"].text' pom.xml || ./mvnw ${BUILD_OPTIONS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate -Dexpression=project.groupId |grep -Ev '(^\[|Download\w+:)' )
    result=$( echo "${result}" | tail -1 )
    echo "${result}"
}

function retrieveAppName() {
    local result=$( ruby -r rexml/document -e 'puts REXML::Document.new(File.new(ARGV.shift)).elements["/project/artifactId"].text' pom.xml || ./mvnw ${BUILD_OPTIONS} org.apache.maven.plugins:maven-help-plugin:2.2:evaluate -Dexpression=project.artifactId |grep -Ev '(^\[|Download\w+:)' )
    result=$( echo "${result}" | tail -1 )
    echo "${result}"
}

function printTestResults() {
    echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 "$( testResultsAntPattern )"
}

function retrieveStubRunnerIds() {
    echo "$( extractMavenProperty 'stubrunner.ids' )"
}

function runSmokeTests() {
    local applicationHost="${APPLICATION_URL}"
    local stubrunnerHost="${STUBRUNNER_URL}"
    echo "Running smoke tests"

    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS} || ( echo "$( printTestResults )" && return 1)
    else
        ./mvnw clean install -Psmoke -Dapplication.url="${applicationHost}" -Dstubrunner.url="${stubrunnerHost}" ${BUILD_OPTIONS}
    fi
}

function runE2eTests() {
    # Retrieves Application URL
    retrieveApplicationUrl
    local applicationHost="${APPLICATION_URL}"
    echo "Running e2e tests"

    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean install -Pe2e -Dapplication.url="${applicationHost}" ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
    else
        ./mvnw clean install -Pe2e -Dapplication.url="${applicationHost}" ${BUILD_OPTIONS}
    fi
}

function outputFolder() {
    echo "target"
}

function testResultsAntPattern() {
    echo "**/surefire-reports/*"
}

export -f build
export -f apiCompatibilityCheck
export -f runSmokeTests
export -f runE2eTests
export -f outputFolder
export -f testResultsAntPattern
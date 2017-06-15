#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."
projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

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
    if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
        if [[ "${CI}" == "CONCOURSE" ]]; then
            ./mvnw clean verify -Papicompatibility -Dlatest.production.version=${LATEST_PROD_VERSION} -Drepo.with.jars=${REPO_WITH_JARS} ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
        else
            ./mvnw clean verify -Papicompatibility -Dlatest.production.version=${LATEST_PROD_VERSION} -Drepo.with.jars=${REPO_WITH_JARS} ${BUILD_OPTIONS}
        fi
    elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
        if [[ "${CI}" == "CONCOURSE" ]]; then
            ./gradlew clean apiCompatibility -DlatestProductionVersion=${LATEST_PROD_VERSION} -DREPO_WITH_JARS=${REPO_WITH_JARS} ${BUILD_OPTIONS} --stacktrace  || ( $( printTestResults ) && return 1)
        else
            ./gradlew clean apiCompatibility -DlatestProductionVersion=${LATEST_PROD_VERSION} -DREPO_WITH_JARS=${REPO_WITH_JARS} ${BUILD_OPTIONS} --stacktrace
        fi
    else
        echo "Unsupported project build tool"
        return 1
    fi
fi

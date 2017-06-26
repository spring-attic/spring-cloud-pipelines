#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Additional Build Options [${BUILD_OPTIONS}]"
echo "Repo with jars [${REPO_WITH_JARS}]"

if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
    ./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${BUILD_OPTIONS}
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${BUILD_OPTIONS} || ( $( printTestResults ) && return 1)
    else
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${BUILD_OPTIONS}
    fi
elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./gradlew clean build deploy -PnewVersion=${PIPELINE_VERSION} -DREPO_WITH_JARS=${REPO_WITH_JARS} ${BUILD_OPTIONS} --stacktrace  || ( $( printTestResults ) && return 1)
    else
        ./gradlew clean build deploy -PnewVersion=${PIPELINE_VERSION} -DREPO_WITH_JARS=${REPO_WITH_JARS} ${BUILD_OPTIONS} --stacktrace
    fi
else
    echo "Unsupported project build tool"
    return 1
fi

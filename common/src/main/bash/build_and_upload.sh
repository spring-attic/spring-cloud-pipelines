#!/bin/bash +x

set -e

source pipeline.sh || echo "No pipeline.sh found"

if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
    ./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${MAVEN_ARGS}
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${MAVEN_ARGS} || echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 target/surefire-reports/* && return 1
    else
        ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${MAVEN_ARGS}
    fi
elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
    if [[ "${CI}" == "CONCOURSE" ]]; then
        ./gradlew clean build deploy -PnewVersion=${PIPELINE_VERSION} -DM2_LOCAL="${M2_LOCAL}" -DREPO_WITH_JARS="${REPO_WITH_JARS}" --stacktrace || echo -e "\n\nBuild failed!!! - will print all test results to the console (it's the easiest way to debug anything later)\n\n" && tail -n +1 build/test-results/*.xml && return 1
    else
        ./gradlew clean build deploy -PnewVersion=${PIPELINE_VERSION} -DM2_LOCAL="${M2_LOCAL}" -DREPO_WITH_JARS="${REPO_WITH_JARS}" --stacktrace
    fi
else
    echo "Unsupported project build tool"
    return 1
fi
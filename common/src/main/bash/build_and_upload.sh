#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )

echo "Project type [${PROJECT_TYPE}]"
echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

if [[ "${PROJECT_TYPE}" == "MAVEN" ]]; then
    ./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${MAVEN_ARGS}
    ./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${MAVEN_ARGS}
elif [[ "${PROJECT_TYPE}" == "GRADLE" ]]; then
    ./gradlew clean build deploy -PnewVersion=${PIPELINE_VERSION} -DM2_LOCAL="${M2_LOCAL}" -DREPO_WITH_JARS="${REPO_WITH_JARS}" --stacktrace
else
    echo "Unsupported project build tool"
    return 1
fi
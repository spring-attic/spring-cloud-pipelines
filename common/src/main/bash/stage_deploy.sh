#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )

echo "Project type [${PROJECT_TYPE}]"
echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app, eureka
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
# Log in to CF to start deployment
logInToCf "${REDOWNLOAD_INFRA}" "${CF_STAGE_USERNAME}" "${CF_STAGE_PASSWORD}" "${CF_STAGE_ORG}" "${CF_STAGE_SPACE}" "${CF_STAGE_API_URL}"
# setup infra
deployRabbitMqToCf
deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${EUREKA_ARTIFACT_ID}" "stage"
# deploy app
deployAndRestartAppWithName ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}" "stage"
propagatePropertiesForTests ${projectArtifactId}
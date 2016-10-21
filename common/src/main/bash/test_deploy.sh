#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )

echo "Project type [${PROJECT_TYPE}]"
echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."
retrieveGroupId
retrieveArtifactId

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app, eureka, stubrunner
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${STUBRUNNER_GROUP_ID} ${STUBRUNNER_ARTIFACT_ID} ${STUBRUNNER_VERSION}
# Log in to CF to start deployment
logInToCf "${REDOWNLOAD_INFRA}" "${CF_TEST_USERNAME}" "${CF_TEST_PASSWORD}" "${CF_TEST_ORG}" "${CF_TEST_SPACE}" "${CF_TEST_API_URL}"
# setup infra
deployRabbitMqToCf
deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${EUREKA_ARTIFACT_ID}" "test"
deployStubRunnerBoot ${REDEPLOY_INFRA} "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}"
# deploy app
deployAndRestartAppWithNameForSmokeTests ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}"
propagatePropertiesForTests ${projectArtifactId}
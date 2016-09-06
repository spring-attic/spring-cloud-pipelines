#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app, eureka, stubrunner
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${STUBRUNNER_GROUP_ID} ${STUBRUNNER_ARTIFACT_ID} ${STUBRUNNER_VERSION}
# Log in to CF to start deployment
logInToCf ${REDOWNLOAD_INFRA} ${CF_TEST_USERNAME} ${CF_TEST_PASSWORD} ${CF_TEST_ORG} ${CF_TEST_SPACE}
# setup infra
deployRabbitMqToCf
deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}"
deployStubRunnerBoot ${REDEPLOY_INFRA} "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}"
# deploy app
deployAndRestartAppWithName ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}"
propagatePropertiesForTests ${projectArtifactId}
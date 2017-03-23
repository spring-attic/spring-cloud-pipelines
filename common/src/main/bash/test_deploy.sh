#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Running retrieval of group and artifactid to download all dependencies. It might take a while..."
retrieveGroupId
retrieveArtifactId

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app, eureka, stubrunner
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
downloadJar 'true' ${REPO_WITH_JARS} ${STUBRUNNER_GROUP_ID} ${STUBRUNNER_ARTIFACT_ID} ${STUBRUNNER_VERSION}
# Log in to CF to start deployment
logInToCf "${REDOWNLOAD_INFRA}" "${CF_TEST_USERNAME}" "${CF_TEST_PASSWORD}" "${CF_TEST_ORG}" "${CF_TEST_SPACE}" "${CF_TEST_API_URL}"
# setup infra (for tests all services need to have unique name so they are not resued between other apps)
UNIQUE_RABBIT_NAME="rabbitmq-${projectArtifactId}"
if [[ "${REDEPLOY_INFRA}" == "true" ]]; then
    UNIQUE_EUREKA_NAME="eureka-${projectArtifactId}"
fi
UNIQUE_MYSQL_NAME="mysql-${projectArtifactId}"
UNIQUE_STUBRUNNER_NAME="stubrunner-${projectArtifactId}"
deployRabbitMqToCf "${UNIQUE_RABBIT_NAME}"
deleteApp "${projectArtifactId}"
deleteMySql "${UNIQUE_MYSQL_NAME}"
deployMySqlToCf "${UNIQUE_MYSQL_NAME}"
deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${UNIQUE_EUREKA_NAME}" "test"
deployStubRunnerBoot 'true' "${STUBRUNNER_ARTIFACT_ID}-${STUBRUNNER_VERSION}" "${REPO_WITH_JARS}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "test" "${UNIQUE_STUBRUNNER_NAME}"
# deploy app
deployAndRestartAppWithNameForSmokeTests ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}" "${UNIQUE_RABBIT_NAME}" "${UNIQUE_EUREKA_NAME}" "${UNIQUE_MYSQL_NAME}"
propagatePropertiesForTests ${projectArtifactId}

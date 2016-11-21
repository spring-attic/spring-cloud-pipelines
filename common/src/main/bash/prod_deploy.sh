#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
# Log in to CF to start deployment
logInToCf "${REDOWNLOAD_INFRA}" "${CF_PROD_USERNAME}" "${CF_PROD_PASSWORD}" "${CF_PROD_ORG}" "${CF_PROD_SPACE}" "${CF_PROD_API_URL}"

# deploying rabbitmq
# TODO: most likely rabbitmq and eureka would be there on production; this remains for demo purposes
deployRabbitMqToCf
downloadJar ${REDEPLOY_INFRA} ${REPO_WITH_JARS} ${EUREKA_GROUP_ID} ${EUREKA_ARTIFACT_ID} ${EUREKA_VERSION}
deployEureka ${REDEPLOY_INFRA} "${EUREKA_ARTIFACT_ID}-${EUREKA_VERSION}" "${EUREKA_ARTIFACT_ID}" "prod" ${DOMAIN}

# deploy app
deployAndRestartAppWithName ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}" "prod" ${DOMAIN}

#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

projectGroupId=$( retrieveGroupId )
projectArtifactId=$( retrieveArtifactId )

# download app, eureka, stubrunner
downloadJar 'true' ${REPO_WITH_JARS} ${projectGroupId} ${projectArtifactId} ${PIPELINE_VERSION}
# Log in to CF to start deployment
logInToCf ${REDOWNLOAD_INFRA} ${CF_PROD_USERNAME} ${CF_PROD_PASSWORD} ${CF_PROD_ORG} ${CF_PROD_SPACE}
# deploy app
deployAndRestartAppWithName ${projectArtifactId} "${projectArtifactId}-${PIPELINE_VERSION}"
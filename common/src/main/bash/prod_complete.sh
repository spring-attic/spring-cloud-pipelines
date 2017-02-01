#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

projectArtifactId=$( retrieveArtifactId )

# Log in to CF to start deployment
logInToCf "${REDOWNLOAD_INFRA}" "${CF_PROD_USERNAME}" "${CF_PROD_PASSWORD}" "${CF_PROD_ORG}" "${CF_PROD_SPACE}" "${CF_PROD_API_URL}"

# Finish the blue green deployment
deleteTheOldApplicationIfPresent "${projectArtifactId}"

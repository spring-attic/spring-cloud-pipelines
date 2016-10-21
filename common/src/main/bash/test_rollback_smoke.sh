#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )

echo "Project type [${PROJECT_TYPE}]"
echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

echo "Application URL [${APPLICATION_URL}]"
echo "StubRunner URL [${STUBRUNNER_URL}]"
echo "Latest production tag [${LATEST_PROD_TAG}]"

if [[ -z "${LATEST_PROD_TAG}" || "${LATEST_PROD_TAG}" == "master" ]]; then
    echo "No prod release took place - skipping this step"
else
    LATEST_PROD_VERSION=$( extractVersionFromProdTag ${LATEST_PROD_TAG} )
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
fi

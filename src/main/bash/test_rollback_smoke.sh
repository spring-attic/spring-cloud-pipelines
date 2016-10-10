#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

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

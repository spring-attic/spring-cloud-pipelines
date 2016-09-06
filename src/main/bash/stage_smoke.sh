#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

if [[ "${LATEST_PROD_TAG}" == "master" ]]; then
    echo "No prod release took place - skipping this step"
else
    runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
fi
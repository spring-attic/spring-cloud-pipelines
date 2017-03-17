#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Application URL [${APPLICATION_URL}]"
echo "StubRunner URL [${STUBRUNNER_URL}]"
echo "Latest production tag [${LATEST_PROD_TAG}]"

prepareForSmokeTests "${REDOWNLOAD_INFRA}" "${CF_TEST_USERNAME}" "${CF_TEST_PASSWORD}" "${CF_TEST_ORG}" "${CF_TEST_SPACE}" "${CF_TEST_API_URL}"

if [[ -z "${LATEST_PROD_TAG}" || "${LATEST_PROD_TAG}" == "master" ]]; then
    echo "No prod release took place - skipping this step"
else
    LATEST_PROD_VERSION=$( extractVersionFromProdTag ${LATEST_PROD_TAG} )
    echo "Last prod version equals ${LATEST_PROD_VERSION}"
    runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
fi

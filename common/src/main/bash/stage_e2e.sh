#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Application URL [${APPLICATION_URL}]"

prepareForE2eTests "${REDOWNLOAD_INFRA}" "${CF_STAGE_USERNAME}" "${CF_STAGE_PASSWORD}" "${CF_STAGE_ORG}" "${CF_STAGE_SPACE}" "${CF_STAGE_API_URL}"

runE2eTests ${APPLICATION_URL}

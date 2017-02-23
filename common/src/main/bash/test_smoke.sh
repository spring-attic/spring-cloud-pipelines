#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" || \
    echo "No pipeline.sh found"

echo "Application URL [${APPLICATION_URL}]"
echo "StubRunner URL [${STUBRUNNER_URL}]"

runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}

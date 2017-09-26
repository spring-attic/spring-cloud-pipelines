#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

# Find latest prod version
export LATEST_PROD_TAG
[[ -z "${LATEST_PROD_TAG}" ]] && LATEST_PROD_TAG="$(findLatestProdTag)"
prepareForSmokeTests
echo "Last prod tag equals [${LATEST_PROD_TAG}]"

if [[ -z "${LATEST_PROD_TAG}" || "${LATEST_PROD_TAG}" == "master" ]]; then
	echo "No prod release took place - skipping this step"
else
	runSmokeTests
fi

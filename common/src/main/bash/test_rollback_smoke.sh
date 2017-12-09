#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

# Find latest prod version
prodTag="$(findLatestProdTag)"
echo "Last prod tag equals [${prodTag}]"

if [[ -z "${prodTag}" || "${prodTag}" == "master" ]]; then
	echo "No prod release took place - skipping this step"
else
	"${GIT_BIN}" checkout "${prodTag}"
	prepareForSmokeTests
	runSmokeTests
fi

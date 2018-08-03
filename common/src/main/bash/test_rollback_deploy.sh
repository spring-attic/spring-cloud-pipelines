#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# If applicable, deploys current prod version to test environment.
# Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

# Find latest prod version
prodTag="$(findLatestProdTag)"
echo "Last prod tag equals [${prodTag}]"
if [[ -z "${prodTag}" ]]; then
	echo "No prod release took place - skipping this step"
else
	"${GIT_BIN}" checkout "${prodTag}"
	testRollbackDeploy "${prodTag}"
fi

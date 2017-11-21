#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

# Find latest prod version
[[ -z "${LATEST_PROD_TAG}" ]] && LATEST_PROD_TAG="$(findLatestProdTag)"
echo "Last prod tag equals [${LATEST_PROD_TAG}]"
if [[ -z "${LATEST_PROD_TAG}" ]]; then
	echo "No prod release took place - skipping this step"
else

#	scPipelinesChanged=""
#	scPipelinesFileName="${PIPELINE_DESCRIPTOR}"
#	git diff "${LATEST_PROD_TAG}:${scPipelinesFileName} ${scPipelinesFileName}" | grep index && scPipelinesChanged="true"
#	if [[ "${scPipelinesChanged}" == "true" ]]; then
#	  echo "MAKE A GIGANTIC SIGN ABOUT THIS"
#	fi

# TODO Also, when test jobs start, re-set mechanism to make sure service updates were done. Or include git version in approval file

	"${GIT_BIN}" checkout "${LATEST_PROD_TAG}"
	testRollbackDeploy "${LATEST_PROD_TAG}"
fi

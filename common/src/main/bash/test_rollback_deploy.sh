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
if [[ -z "${prodTag}" ]]; then
	echo "No prod release took place - skipping this step"
else

#	scPipelinesChanged=""
#	scPipelinesFileName="${PIPELINE_DESCRIPTOR}"
#	git diff "${LATEST_PROD_TAG}:${scPipelinesFileName} ${scPipelinesFileName}" | grep index && scPipelinesChanged="true"
#	if [[ "${scPipelinesChanged}" == "true" ]]; then
#	  echo "MAKE A GIGANTIC SIGN ABOUT THIS"
#	fi

# TODO Also, when test jobs start, re-set mechanism to make sure service updates were done. Or include git version in approval file

	"${GIT_BIN}" checkout "${prodTag}"
	testRollbackDeploy "${prodTag}"
fi

#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Rolls back app from production. Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=PROD

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

if rollbackToPreviousVersion; then
	echo "Deleting production tag"
	tagName="prod/${PROJECT_NAME}/${PIPELINE_VERSION}"
	"${GIT_BIN}" push --delete origin "${tagName}"
	exit 0
else
	echo "Failed to rollback to previous version"
	exit 1
fi

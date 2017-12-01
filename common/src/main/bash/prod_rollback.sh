#!/bin/bash

set -o errexit

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=PROD

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

echo "Loading git key to enable tag deletion"
export TMPDIR=/tmp
echo "${GIT_PRIVATE_KEY}" > "${TMPDIR}/git-resource-private-key"
load_pubkey

if rollbackToPreviousVersion; then
	echo "Deleting production tag"
	tagName="prod/${PIPELINE_VERSION}"
	"${GIT_BIN}" push --delete origin "${tagName}"
	exit 0
else
	echo "Failed to rollback to previous version"
	exit 1
fi

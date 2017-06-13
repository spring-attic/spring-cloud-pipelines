#!/bin/bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

__dir="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )"

REPOSITORIES="github-webhook github-analytics"

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <GH organization name>"
	exit 1
fi

GH_ORG="$1"

mkdir -p "${__dir}/../target" && cd "${__dir}/../target"

for REPO in ${REPOSITORIES}; do
	if [[ ! -d "${REPO}" ]]; then
		git clone "git@github.com:${GH_ORG}/${REPO}.git"
	else
		git fetch --prune --tags
	fi
	pushd "${REPO}"
	git tag --list | grep '^prod/' | xargs -n1 git push --delete origin
	popd
done

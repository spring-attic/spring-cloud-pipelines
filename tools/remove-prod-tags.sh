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
	fi
	pushd "${REPO}"
	while read -r TAG; do
		git push --delete origin "${TAG}"
	done < <( git ls-remote -q --tags origin | cut -f 2 | grep '^refs/tags/prod/' | grep -v '{}' )
	popd
done

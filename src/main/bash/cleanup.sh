#!/usr/bin/env bash

# Call this script from the root of the project

source common.sh || source src/main/bash/common.sh || echo "No common.sh script found..."

set -o errexit
set -o errtrace
set -o pipefail

VERSION="${1:?YOU MUST PASS THE VERSION AS AN ARGUMENT OF THIS SCRIPT!!}"
PREVIOUS_VERSION="${2:-}"

if [[ ${PREVIOUS_VERSION} = *"SNAPSHOT"* ]]; then
	echo "Won't do anything since [${PREVIOUS_VERSION}] is a snapshot version"
else
	echo "Setting back the version and building old docs"
	pushd docs-sources
	./mvnw org.codehaus.mojo:versions-maven-plugin:2.3:set -DnewVersion="${VERSION}"
	./mvnw clean install -Pdocs
	popd

	retrieve_current_branch

	echo "Committing changes"
	git add .
	git commit -a -m "Going back to snapshots"
	git push origin "${CURRENT_BRANCH}"
fi

echo "Done!"
checkout_previous_branch

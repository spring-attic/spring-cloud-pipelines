#!/usr/bin/env bash

# Call this script from the root of the project

set -o errexit
set -o errtrace
set -o pipefail

VERSION="${1:?YOU MUST PASS THE VERSION AS AN ARGUMENT OF THIS SCRIPT!!}"

echo "Setting back the version and building old docs"
pushd docs-sources
./mvnw org.codehaus.mojo:versions-maven-plugin:2.3:set -DnewVersion="${VERSION}"
./mvnw clean install -Pdocs
popd

echo "Committing changes"
git add .
git commit -a -m "Going back to snapshots"
git push origin master

echo "Done!"

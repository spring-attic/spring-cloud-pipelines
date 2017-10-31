#!/usr/bin/env bash

# Call this script from the root of the project

set -o errexit
set -o errtrace
set -o pipefail

VERSION="${1:?YOU MUST PASS THE VERSION AS AN ARGUMENT OF THIS SCRIPT!!}"
SPRING_CLOUD_STATIC_REPO="${SPRING_CLOUD_STATIC_REPO:-git@github.com:spring-cloud/spring-cloud-static.git}"
SC_STATIC_OUTPUT="${SC_STATIC_OUTPUT:-build/sc-static}"
PROJECT_SUBFOLDER="spring-cloud-pipelines/${VERSION}"
SC_STATIC_PROJECT_FOLDER="${SC_STATIC_OUTPUT}/${PROJECT_SUBFOLDER}"
TAG_NAME="v${VERSION}"

echo "Will create version [${VERSION}] of sc-pipelines documentation"

echo "Cloning spring cloud static [${SPRING_CLOUD_STATIC_REPO}] to [${SC_STATIC_OUTPUT}]"
rm -rf "${SC_STATIC_OUTPUT}"
mkdir "${SC_STATIC_OUTPUT}" -p
git clone -b gh-pages "${SPRING_CLOUD_STATIC_REPO}" --single-branch "${SC_STATIC_OUTPUT}"

echo "Creating subfolder [${PROJECT_SUBFOLDER}]"
mkdir -p "${SC_STATIC_PROJECT_FOLDER}"

echo "Copying the docs to sc-static"
cp docs/spring-cloud-pipelines.html "${SC_STATIC_PROJECT_FOLDER}/index.html"
cp -r docs/css "${SC_STATIC_PROJECT_FOLDER}/"
cp -r docs/images "${SC_STATIC_PROJECT_FOLDER}/"
cp -r docs/single "${SC_STATIC_PROJECT_FOLDER}/"
cp -r docs/multi "${SC_STATIC_PROJECT_FOLDER}/"

echo "Committing docs changes"
pushd "${SC_STATIC_PROJECT_FOLDER}/../"
git add "${VERSION}"
git commit -a -m "Sync docs from v${VERSION} to gh-pages"
git push origin gh-pages
popd

echo "Tagging the repo"
git add .
git commit -a -m "Update SNAPSHOT to ${VERSION}"
git tag "${TAG_NAME}"
git push origin "${TAG_NAME}"

echo "Done!"

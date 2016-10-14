#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

./mvnw versions:set -DnewVersion=${PIPELINE_VERSION} ${MAVEN_ARGS}
./mvnw clean verify deploy -Ddistribution.management.release.id=${M2_SETTINGS_REPO_ID} -Ddistribution.management.release.url=${REPO_WITH_JARS} ${MAVEN_ARGS}
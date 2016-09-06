#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

./mvnw clean verify deploy -Dversion=${PIPELINE_VERSION}
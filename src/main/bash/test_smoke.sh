#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

echo "Application URL [${APPLICATION_URL}]"
echo "StubRunner URL [${STUBRUNNER_URL}]"

runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
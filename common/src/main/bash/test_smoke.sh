#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

export PROJECT_TYPE=$( projectType )
export OUTPUT_FOLDER=$( outputFolder )
export TEST_REPORTS_FOLDER=$( testResultsFolder )

echo "Project type [${PROJECT_TYPE}]"
echo "Output folder [${OUTPUT_FOLDER}]"
echo "Test reports folder [${TEST_REPORTS_FOLDER}]"

echo "Application URL [${APPLICATION_URL}]"
echo "StubRunner URL [${STUBRUNNER_URL}]"

runSmokeTests ${APPLICATION_URL} ${STUBRUNNER_URL}
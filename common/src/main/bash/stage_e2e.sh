#!/bin/bash

set -e

source pipeline.sh || echo "No pipeline.sh found"

echo "Application URL [${APPLICATION_URL}]"

runE2eTests ${APPLICATION_URL}
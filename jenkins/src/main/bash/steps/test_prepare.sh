#!/bin/bash
set -o errexit
set -o errtrace
set -o pipefail

export PAAS_TYPE=CF
export ENVIRONMENT=TEST

# shellcheck source=/dev/null
source "${WORKSPACE}"/.git/tools/common/src/main/bash/pipeline.sh

# Log in to PaaS to start deployment
logInToPaas

deployServices
waitForServicesToInitialize

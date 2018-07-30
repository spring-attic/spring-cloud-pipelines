#!/bin/bash
set -o errexit
set -o errtrace
set -o pipefail

export ENVIRONMENT=prod

# shellcheck source=/dev/null
source "${WORKSPACE}"/.git/tools/common/src/main/bash/pipeline.sh

removeProdTag

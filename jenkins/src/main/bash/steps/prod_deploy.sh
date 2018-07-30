#!/bin/bash
set -o errexit
set -o errtrace
set -o pipefail

# shellcheck source=/dev/null
"${WORKSPACE}"/.git/tools/common/src/main/bash/prod_deploy.sh

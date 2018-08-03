#!/bin/bash
set -o errexit
set -o errtrace
set -o pipefail

# shellcheck source=/dev/null
"${WORKSPACE}"/.git/tools/common/src/main/bash/stage_e2e.sh

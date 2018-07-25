#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Runs smoke tests on the test environment. Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=TEST

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

prepareForSmokeTests
runSmokeTests

#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Runs end to end tests on stage. Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=STAGE

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

prepareForE2eTests
runE2eTests

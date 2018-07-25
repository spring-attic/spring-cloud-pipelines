#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Executes a build of the project. Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=BUILD

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

build

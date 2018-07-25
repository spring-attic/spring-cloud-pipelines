#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Executes a switch over of the traffic, fully to the new instance.
# Sources pipeline.sh
# }}}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ENVIRONMENT=PROD

# shellcheck source=/dev/null
[[ -f "${__DIR}/pipeline.sh" ]] && source "${__DIR}/pipeline.sh" ||  \
 echo "No pipeline.sh found"

completeSwitchOver

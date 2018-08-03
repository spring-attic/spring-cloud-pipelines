#!/bin/bash

export ENVIRONMENT=prod

# shellcheck source=/dev/null
source "${WORKSPACE}"/.git/tools/common/src/main/bash/pipeline.sh

removeProdTag

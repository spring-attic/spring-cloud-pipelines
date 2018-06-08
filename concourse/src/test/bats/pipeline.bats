#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"

	cp -a "${FIXTURES_DIR}/generic" "${TEMP_DIR}"

	# Copying the common folder
	NEW_SRC="${TEMP_DIR}/generic/project/tools/common/src/main/bash"
	mkdir -p "${NEW_SRC}"
	cp "${FIXTURES_DIR}/pipeline-dummy.sh" "${NEW_SRC}/pipeline.sh"

	# Copying the concourse folder
	NEW_CONCOURSE_SRC="${TEMP_DIR}/generic/project/tools/concourse/"
	mkdir -p "${NEW_CONCOURSE_SRC}"
	cp -r "${SOURCE_DIR}" "${NEW_CONCOURSE_SRC}"

	export ROOT_FOLDER="${TEMP_DIR}/generic/project"
	export REPO_RESOURCE="repo"
	export TOOLS_RESOURCE="tools"
	export KEYVAL_RESOURCE="keyval"
	export M2_HOME="${TEMP_DIR}/generic/project/user_home"
	export GRADLE_HOME="${GRADLE_HOME}/generic/project/user_home"
}

@test "should source pipeline.sh from common" {
	export PAAS_TYPE="cf"
	export PROJECT_TYPE="dummy"

	source "${SOURCE_DIR}/pipeline.sh"

	assert_success
}

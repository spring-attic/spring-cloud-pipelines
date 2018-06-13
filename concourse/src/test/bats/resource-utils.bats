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
	export PAAS_TYPE="cf"
	cp "${COMMON_DIR}"/*.sh "${NEW_SRC}/"
	cp -f "${FIXTURES_DIR}/pipeline-dummy.sh" "${NEW_SRC}/pipeline-cf.sh"

	# Copying the concourse folder
	NEW_CONCOURSE_SRC="${TEMP_DIR}/generic/project/tools/concourse/"
	mkdir -p "${NEW_CONCOURSE_SRC}"
	cp -r "${SOURCE_DIR}" "${NEW_CONCOURSE_SRC}"

	export ROOT_FOLDER="${TEMP_DIR}/generic/project"
	export REPO_RESOURCE="repo"
	export TOOLS_RESOURCE="tools"
	export KEYVAL_RESOURCE="keyval"
	export M2_HOME="${TEMP_DIR}/generic/project/user_home"
	export GRADLE_HOME="${TEMP_DIR}/generic/project/user_home"
	export SSH_HOME="${TEMP_DIR}/generic/project/ssh"
	mkdir -p "${SSH_HOME}"
	export TEST_MODE="true"
	export SSH_AGENT_BIN="stubbed-ssh-agent"
	export TMPDIR="${TEMP_DIR}/generic/project/tmp"
	mkdir -p "${TMPDIR}"
}

teardown() {
	rm -rf "${TEMP_DIR}"
}

function stubbed-ssh-agent() {
	echo "echo 'foo'"
}

export -f stubbed-ssh-agent

@test "should read key value pairs" {
	source "${TASKS_DIR}/resource-utils.sh"
	echo "foo=bar" > "${ROOT_FOLDER}/${KEYVAL_RESOURCE}"/keyval.properties

	exportKeyValProperties

	assert_success
	assert_equal "${foo}" "bar"
}

@test "should write all env vars starting with PASSED_ to file" {
	source "${TASKS_DIR}/resource-utils.sh"
	export PASSED_BAR="BAZ"

	passKeyValProperties

	assert_success
	properties="$( cat ${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}/keyval.properties )"
	assert_equal "${properties}" "PASSED_BAR=BAZ"
}

@test "should load public key" {
	export SSH_AGENT_BIN="stubbed-ssh-agent"
	export TMPDIR="${SSH_HOME}"
	echo "hello" > "${TMPDIR}/git-resource-private-key"
	source "${TASKS_DIR}/resource-utils.sh"

	load_pubkey

	assert_success
	assert_equal "$(permission "${TMPDIR}/git-resource-private-key")" "600"
	assert_equal "$(permission "${SSH_HOME}"/config)" "600"
}

function permission() {
	case "`uname`" in
		Darwin*) stat -f '%A' "${1}" ;;
		*) stat -c '%a' "${1}" ;;
	esac
}

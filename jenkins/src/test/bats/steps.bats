#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"

	mkdir -p "${TEMP_DIR}/scripts"
	cp -a "${FIXTURES_DIR}/scripts" "${TEMP_DIR}"

	# Copying the common folder
	NEW_SRC="${TEMP_DIR}/.git/tools/common/src/main/bash/"
	mkdir -p "${NEW_SRC}"
	cp "${TEMP_DIR}"/scripts/*.sh "${NEW_SRC}/"

	export WORKSPACE="${TEMP_DIR}"
}

teardown() {
	rm -rf "${TEMP_DIR}"
}

@test "should run test_deploy" {
	export SCRIPT_NAME="test_deploy"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run test_smoke" {
	export SCRIPT_NAME="test_smoke"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run test_rollback_deploy" {
	export SCRIPT_NAME="test_rollback_deploy"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run test_rollback_smoke" {
	export SCRIPT_NAME="test_rollback_smoke"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run stage_deploy" {
	export SCRIPT_NAME="stage_deploy"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run stage_e2e" {
	export SCRIPT_NAME="stage_e2e"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run prod_deploy" {
	export SCRIPT_NAME="prod_deploy"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run prod_complete" {
	export SCRIPT_NAME="prod_complete"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run prod_rollback" {
	export SCRIPT_NAME="prod_rollback"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "Executed ${SCRIPT_NAME}"
}

@test "should run prod_remove_tag" {
	export SCRIPT_NAME="prod_remove_prod_tag"
	run "${STEPS_DIR}"/${SCRIPT_NAME}.sh

	assert_success
	assert_output "removeProdTag"
}

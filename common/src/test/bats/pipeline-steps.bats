#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export PAAS_TYPE="dummy"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
}

teardown() {
	rm -f -- "${SOURCE_DIR}/pipeline-dummy.sh"
}

function git() {
	echo "git $*"
}

function git_empty() {
	echo ""
}

function git_master() {
	echo "master"
}

export -f git
export -f git_empty
export -f git_master

@test "should run build for build_and_upload" {
	run "${SOURCE_DIR}/build_and_upload.sh"

	assert_output --partial "build"
}

@test "should run apiCompatibilityCheck for build_api_compatibility_check" {
	run "${SOURCE_DIR}/build_api_compatibility_check.sh"

	assert_output --partial "apiCompatibilityCheck"
}

@test "should run testDeploy for testDeploy" {
	run "${SOURCE_DIR}/test_deploy.sh"

	assert_output --partial "testDeploy"
}

@test "should run smoke tests for test_smoke" {
	run "${SOURCE_DIR}/test_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	assert_output --partial "runSmokeTests"
}

@test "should do nothing if there's no prod deployment for rollback deployment" {
	export GIT_BIN="git_empty"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	refute_output "testRollbackDeploy"
	assert_output --partial --partial "Last prod tag equals []"
	assert_output --partial "No prod release took place - skipping this step"
}

@test "should call testRollbackDeploy with latest prod version" {
	export LATEST_PROD_TAG="100.0.0"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	assert_output --partial "Last prod tag equals [100.0.0]"
	assert_output --partial "testRollbackDeploy [100.0.0]"
}

@test "should do nothing if there's no prod deployment for rollback test" {
	export GIT_BIN="git_empty"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	refute_output --partial "prepareForSmokeTests"
	refute_output "testRollbackDeploy"
	assert_output --partial "Last prod tag equals []"
	assert_output --partial "No prod release took place - skipping this step"
}

@test "should do nothing if there's prod tag is 'master' for rollback test" {
	export GIT_BIN="git_master"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	refute_output --partial "prepareForSmokeTests"
	refute_output "testRollbackDeploy"
	assert_output --partial "Last prod tag equals [master]"
	assert_output --partial "No prod release took place - skipping this step"
}

@test "should call runSmokeTests with latest prod version for rollback tests" {
	export LATEST_PROD_TAG="100.0.0"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	assert_output --partial "Last prod tag equals [100.0.0]"
	assert_output --partial "runSmokeTests"
}

@test "should run stage deployment for stage_deploy" {
	run "${SOURCE_DIR}/stage_deploy.sh"

	assert_output --partial "stageDeploy"
}

@test "should run stage deployment for stage_e2e" {
	run "${SOURCE_DIR}/stage_e2e.sh"

	assert_output --partial "prepareForE2eTests"
	assert_output --partial "runE2eTests"
}

@test "should run prod deployment for prod_deploy" {
	run "${SOURCE_DIR}/prod_deploy.sh"

	assert_output --partial "prodDeploy"
}

@test "should delete blue instance for prod_complete" {
	run "${SOURCE_DIR}/prod_complete.sh"

	assert_output --partial "completeSwitchOver"
}

@test "should rollback to blue instance for prod_rollback" {
	run "${SOURCE_DIR}/prod_rollback.sh"

	assert_output --partial "rollbackToPreviousVersion"
}

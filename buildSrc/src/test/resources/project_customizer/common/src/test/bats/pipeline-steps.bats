#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export PAAS_TYPE="dummy"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

function findLatestProdTag {
    echo ""
}

@test "should run build for build_and_upload" {
	source "${PIPELINES_TEST_DIR}/build_and_upload.sh"
	run "${PIPELINES_TEST_DIR}/build_and_upload.sh"

	assert_output --partial "build"
	assert_equal "${ENVIRONMENT}" "BUILD"
}

@test "should run apiCompatibilityCheck for build_api_compatibility_check" {
	source "${PIPELINES_TEST_DIR}/build_api_compatibility_check.sh"
	run "${PIPELINES_TEST_DIR}/build_api_compatibility_check.sh"

	assert_output --partial "apiCompatibilityCheck"
	assert_equal "${ENVIRONMENT}" "BUILD"
}

@test "should run testDeploy for testDeploy" {
	source "${PIPELINES_TEST_DIR}/test_deploy.sh"
	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

	assert_output --partial "testDeploy"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should run smoke tests for test_smoke" {
	source "${PIPELINES_TEST_DIR}/test_smoke.sh"
	run "${PIPELINES_TEST_DIR}/test_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	assert_output --partial "runSmokeTests"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should do nothing if there's no prod deployment for rollback deployment" {
	source "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"
	run "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"

	refute_output "testRollbackDeploy"
	assert_output --partial --partial "Last prod tag equals []"
	assert_output --partial "No prod release took place - skipping this step"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should call testRollbackDeploy with latest prod version" {
	export LATEST_PROD_TAG="100.0.0"

	source "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"
	run "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"

	assert_output --partial "Last prod tag equals [100.0.0]"
	assert_output --partial "testRollbackDeploy [100.0.0]"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should do nothing if there's no prod deployment for rollback test" {
	source "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"
	run "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	refute_output "testRollbackDeploy"
	assert_output --partial "Last prod tag equals []"
	assert_output --partial "No prod release took place - skipping this step"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should do nothing if there's prod tag is 'master' for rollback test" {
	export LATEST_PROD_TAG="master"

	source "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"
	run "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	refute_output "testRollbackDeploy"
	assert_output --partial "Last prod tag equals [master]"
	assert_output --partial "No prod release took place - skipping this step"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should call runSmokeTests with latest prod version for rollback tests" {
	export LATEST_PROD_TAG="100.0.0"

	source "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"
	run "${PIPELINES_TEST_DIR}/test_rollback_smoke.sh"

	assert_output --partial "prepareForSmokeTests"
	assert_output --partial "Last prod tag equals [100.0.0]"
	assert_output --partial "runSmokeTests"
	assert_equal "${ENVIRONMENT}" "TEST"
}

@test "should run stage deployment for stage_deploy" {
	source "${PIPELINES_TEST_DIR}/stage_deploy.sh"
	run "${PIPELINES_TEST_DIR}/stage_deploy.sh"

	assert_output --partial "stageDeploy"
	assert_equal "${ENVIRONMENT}" "STAGE"
}

@test "should run stage deployment for stage_e2e" {
	source "${PIPELINES_TEST_DIR}/stage_e2e.sh"
	run "${PIPELINES_TEST_DIR}/stage_e2e.sh"

	assert_output --partial "prepareForE2eTests"
	assert_output --partial "runE2eTests"
	assert_equal "${ENVIRONMENT}" "STAGE"
}

@test "should run prod deployment for prod_deploy" {
	source "${PIPELINES_TEST_DIR}/prod_deploy.sh"
	run "${PIPELINES_TEST_DIR}/prod_deploy.sh"

	assert_output --partial "prodDeploy"
	assert_equal "${ENVIRONMENT}" "PROD"
}

@test "should delete blue instance for prod_complete" {
	source "${PIPELINES_TEST_DIR}/prod_complete.sh"
	run "${PIPELINES_TEST_DIR}/prod_complete.sh"

	assert_output --partial "completeSwitchOver"
	assert_equal "${ENVIRONMENT}" "PROD"
}

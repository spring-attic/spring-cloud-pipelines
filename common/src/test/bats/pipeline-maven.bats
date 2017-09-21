#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

@test "should set BUILD_OPTIONS if there were none" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should append security props for BUILD_OPTIONS if it wasn't set" {
	export BUILD_OPTIONS="foo"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "foo -Djava.security.egd=file:///dev/urandom"
}

@test "should not append additional security props for BUILD_OPTIONS if it wasn't set" {
	export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should return 'target' for outputFolder" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run outputFolder

	assert_output "target"
}

@test "should return maven test results for testResultsAntPattern" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run testResultsAntPattern

	assert_output "**/surefire-reports/*"
}

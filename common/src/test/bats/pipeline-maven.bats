#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="dummy"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	cp -a "${FIXTURES_DIR}/maven" "${TEMP_DIR}"
}

teardown() {
	rm -rf -- "${TEMP_DIR}" "${SOURCE_DIR}/pipeline-dummy.sh"
}

@test "should set BUILD_OPTIONS if there were none [Maven]" {
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should append security props for BUILD_OPTIONS if it wasn't set [Maven]" {
	export BUILD_OPTIONS="foo"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "foo -Djava.security.egd=file:///dev/urandom"
}

@test "should not append additional security props for BUILD_OPTIONS if it wasn't set [Maven]" {
	export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should set a version and execute build for Concourse [Maven]" {
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	export REPO_WITH_BINARIES="baz"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/baz"
	assert_output --partial "maven-deploy-plugin"
	assert_success
}

@test "should print test results when build failed for Jenkins [Maven]" {
	export BUILD_OPTIONS="invalid option"
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
	assert_failure
}

@test "should set a version and execute build for Jenkins [Maven]" {
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	export REPO_WITH_BINARIES="baz"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/baz"
	assert_output --partial "maven-deploy-plugin"
	assert_success
}

@test "should print test results when build failed for Concourse [Maven]" {
	export BUILD_OPTIONS="invalid option"
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
	assert_failure
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck [Maven]" {
	export BUILD_OPTIONS="invalid option"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
	assert_success
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Concourse [Maven]" {
	export CI="CONCOURSE"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Jenkins [Maven]" {
	export CI="JENKINS"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should print a property value if it exists [Maven]" {
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "foo.bar" )"

	assert_equal "${result}" "baz"
}

@test "should print empty string if it doesn't exist [Maven]" {
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "missing" )"

	assert_equal "${result}" ""
}

@test "should print empty string if it doesn't exist and _JAVA_OPTIONS are passed [Maven]" {
	export _JAVA_OPTIONS="-Dfoo=bar"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "missing" )"

	assert_equal "${result}" ""
}

@test "should print group id [Maven]" {
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run retrieveGroupId

	assert_output "com.example"
	assert_success
}

@test "should print artifact id [Maven]" {
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run retrieveAppName

	assert_output "my-project"
	assert_success
}

@test "should print that build has failed [Maven]" {
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run printTestResults

	assert_output --partial "Build failed!!!"
	assert_failure
}

@test "should print stubrunner ids property [Maven]" {
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run retrieveStubRunnerIds

	assert_output --partial "foo.bar:baz"
	assert_success
}

@test "should run the smoke tests for Concourse [Maven]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should run the smoke tests for Jenkins [Maven]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should run the e2e tests for Concourse [Maven]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run runE2eTests

	assert_output --partial "E2E [foo]"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should run the e2e tests for Jenkins [Maven]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	cd "${TEMP_DIR}/maven/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run runE2eTests

	assert_output --partial "E2E [foo]"
	assert_output --partial "maven-surefire-plugin"
	assert_success
}

@test "should return 'target' for outputFolder [Maven]" {
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run outputFolder

	assert_output "target"
	assert_success
}

@test "should return maven test results for testResultsAntPattern [Maven]" {
	source "${SOURCE_DIR}/projectType/pipeline-maven.sh"

	run testResultsAntPattern

	assert_output "**/surefire-reports/*"
	assert_success
}

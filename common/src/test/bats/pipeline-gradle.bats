#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="dummy"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	cp -a "${FIXTURES_DIR}/gradle" "${TEMP_DIR}"
}

teardown() {
	rm -rf -- "${TEMP_DIR}" "${SOURCE_DIR}/pipeline-dummy.sh"
}

@test "should set BUILD_OPTIONS if there were none [Gradle]" {
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should append security props for BUILD_OPTIONS if it wasn't set [Gradle]" {
	export BUILD_OPTIONS="foo"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "foo -Djava.security.egd=file:///dev/urandom"
}

@test "should not append additional security props for BUILD_OPTIONS if it wasn't set [Gradle]" {
	export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should set a version and execute build for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial ":jar"
	assert [ -e "${TEMP_DIR}/gradle/build_project/build/libs/my-project-100.0.0.jar" ]
	assert_success
}

@test "should print test results when build failed for Jenkins [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial "Build failed!!!"
	assert_failure
}

@test "should set a version and execute build for Jenkins [Gradle]" {
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial ":jar"
	assert [ -e "${TEMP_DIR}/gradle/build_project/build/libs/my-project-100.0.0.jar" ]
	assert_success
}

@test "should print test results when build failed for Concourse [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial "Build failed!!!"
	assert_failure
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
	assert_success
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "latestProductionVersion [100.0.0]"
	assert_output --partial ":apiCompatibility"
	assert_success
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Jenkins [Gradle]" {
	export CI="JENKINS"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "latestProductionVersion [100.0.0]"
	assert_output --partial ":apiCompatibility"
	assert_success
}

@test "should print group id [Gradle]" {
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveGroupId )"

	assert_equal "${result}" "com.example"
}

@test "should print artifact id [Gradle]" {
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveAppName )"

	assert_equal "${result}" "my-project"
}

@test "should print that build has failed [Gradle]" {
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run printTestResults

	assert_output --partial "Build failed!!!"
}

@test "should print stubrunner ids property [Gradle]" {
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveStubRunnerIds )"

	assert_equal "${result}" "foo.bar:baz"
}

@test "should run the smoke tests for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run runSmokeTests

	assert_output --partial "application.url [foo]"
	assert_output --partial "stubrunner.url [bar]"
	assert_output --partial ":smoke"
	assert_success
}

@test "should run the smoke tests for Jenkins [Gradle]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run runSmokeTests

	assert_output --partial "application.url [foo]"
	assert_output --partial "stubrunner.url [bar]"
	assert_output --partial ":smoke"
	assert_success
}

@test "should run the e2e tests for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run runE2eTests

	assert_output --partial "application.url [foo]"
	assert_output --partial ":e2e"
	assert_success
}

@test "should run the e2e tests for Jenkins [Gradle]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run runE2eTests

	assert_output --partial "application.url [foo]"
	assert_output --partial ":e2e"
	assert_success
}

@test "should return 'target' for outputFolder [Gradle]" {
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run outputFolder

	assert_output "build/libs"
}

@test "should return gradle test results for testResultsAntPattern [Gradle]" {
	source "${SOURCE_DIR}/projectType/pipeline-gradle.sh"

	run testResultsAntPattern

	assert_output "**/test-results/**/*.xml"
}

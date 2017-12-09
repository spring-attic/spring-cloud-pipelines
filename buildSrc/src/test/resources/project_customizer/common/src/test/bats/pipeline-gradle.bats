#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

@test "should set BUILD_OPTIONS if there were none [Gradle]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should append security props for BUILD_OPTIONS if it wasn't set [Gradle]" {
	export BUILD_OPTIONS="foo"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "foo -Djava.security.egd=file:///dev/urandom"
}

@test "should not append additional security props for BUILD_OPTIONS if it wasn't set [Gradle]" {
	export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should set a version and execute build for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial ":jar"
	assert [ -e "${PIPELINES_TEST_DIR}/gradle/build_project/build/libs/my-project-100.0.0.jar" ]
}

@test "should print test results when build failed for Jenkins [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial "Build failed!!!"
}

@test "should set a version and execute build for Jenkins [Gradle]" {
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial ":jar"
    assert [ -e "${PIPELINES_TEST_DIR}/gradle/build_project/build/libs/my-project-100.0.0.jar" ]
}

@test "should print test results when build failed for Concourse [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run build

	assert_output --partial "Build failed!!!"
}

function findLatestProdTag {
    echo ""
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck [Gradle]" {
	export BUILD_OPTIONS="invalid option"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "latestProductionVersion [100.0.0]"
	assert_output --partial ":apiCompatibility"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Jenkins [Gradle]" {
	export CI="JENKINS"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "latestProductionVersion [100.0.0]"
	assert_output --partial ":apiCompatibility"
}

@test "should print group id [Gradle]" {
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveGroupId )"

	assert_equal "${result}" "com.example"
}

@test "should print artifact id [Gradle]" {
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveAppName )"

	assert_equal "${result}" "my-project"
}

@test "should print that build has failed [Gradle]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run printTestResults

	assert_output --partial "Build failed!!!"
}

@test "should print stubrunner ids property [Gradle]" {
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	result="$( retrieveStubRunnerIds )"

	assert_equal "${result}" "foo.bar:baz"
}

@test "should run the smoke tests for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run runSmokeTests

	assert_output --partial "application.url [foo]"
	assert_output --partial "stubrunner.url [bar]"
	assert_output --partial ":smoke"
}

@test "should run the smoke tests for Jenkins [Gradle]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run runSmokeTests

	assert_output --partial "application.url [foo]"
	assert_output --partial "stubrunner.url [bar]"
	assert_output --partial ":smoke"
}

@test "should run the e2e tests for Concourse [Gradle]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run runE2eTests

	assert_output --partial "application.url [foo]"
	assert_output --partial ":e2e"
}

@test "should run the e2e tests for Jenkins [Gradle]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	cd "${PIPELINES_TEST_DIR}/gradle/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run runE2eTests

	assert_output --partial "application.url [foo]"
	assert_output --partial ":e2e"
}

@test "should return 'target' for outputFolder [Gradle]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run outputFolder

	assert_output "build/libs"
}

@test "should return gradle test results for testResultsAntPattern [Gradle]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-gradle.sh"

	run testResultsAntPattern

	assert_output "**/test-results/*.xml"
}

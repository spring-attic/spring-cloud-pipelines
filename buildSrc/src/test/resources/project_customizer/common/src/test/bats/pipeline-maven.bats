#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

@test "should set BUILD_OPTIONS if there were none [Maven]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should append security props for BUILD_OPTIONS if it wasn't set [Maven]" {
	export BUILD_OPTIONS="foo"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "foo -Djava.security.egd=file:///dev/urandom"
}

@test "should not append additional security props for BUILD_OPTIONS if it wasn't set [Maven]" {
	export BUILD_OPTIONS="-Djava.security.egd=file:///dev/urandom"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	assert_equal "${BUILD_OPTIONS}" "-Djava.security.egd=file:///dev/urandom"
}

@test "should set a version and execute build for Concourse [Maven]" {
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/bar"
	assert_output --partial "maven-deploy-plugin"
}

@test "should print test results when build failed for Jenkins [Maven]" {
	export BUILD_OPTIONS="invalid option"
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
}

@test "should set a version and execute build for Jenkins [Maven]" {
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/bar"
	assert_output --partial "maven-deploy-plugin"
}

@test "should print test results when build failed for Concourse [Maven]" {
	export BUILD_OPTIONS="invalid option"
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES_FOR_UPLOAD="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
}

function findLatestProdTag {
    echo ""
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck [Maven]" {
	export BUILD_OPTIONS="invalid option"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Concourse [Maven]" {
	export CI="CONCOURSE"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
	assert_output --partial "maven-surefire-plugin"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Jenkins [Maven]" {
	export CI="JENKINS"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
	assert_output --partial "maven-surefire-plugin"
}

@test "should print a property value if it exists [Maven]" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "foo.bar" )"

	assert_equal "${result}" "baz"
}

@test "should print empty string if it doesn't exist [Maven]" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "missing" )"

	assert_equal "${result}" ""
}

@test "should print empty string if it doesn't exist and _JAVA_OPTIONS are passed [Maven]" {
	export _JAVA_OPTIONS="-Dfoo=bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	result="$( extractMavenProperty "missing" )"

	assert_equal "${result}" ""
}

@test "should print group id [Maven]" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveGroupId

	assert_output "com.example"
}

@test "should print artifact id [Maven]" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveAppName

	assert_output "my-project"
}

@test "should print that build has failed [Maven]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run printTestResults

	assert_output --partial "Build failed!!!"
}

@test "should print stubrunner ids property [Maven]" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveStubRunnerIds

	assert_output --partial "foo.bar:baz"
}

@test "should run the smoke tests for Concourse [Maven]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
	assert_output --partial "maven-surefire-plugin"
}

@test "should run the smoke tests for Jenkins [Maven]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
	assert_output --partial "maven-surefire-plugin"
}

@test "should run the e2e tests for Concourse [Maven]" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runE2eTests

	assert_output --partial "E2E [foo]"
	assert_output --partial "maven-surefire-plugin"
}

@test "should run the e2e tests for Jenkins [Maven]" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runE2eTests

	assert_output --partial "E2E [foo]"
	assert_output --partial "maven-surefire-plugin"
}

@test "should return 'target' for outputFolder [Maven]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run outputFolder

	assert_output "target"
}

@test "should return maven test results for testResultsAntPattern [Maven]" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run testResultsAntPattern

	assert_output "**/surefire-reports/*"
}

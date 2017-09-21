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

@test "should set a version and execute build from maven for Concourse" {
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/bar"
}

@test "should set a version and execute build from maven for Jenkins" {
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "from version 1.0.0.BUILD-SNAPSHOT to 100.0.0"
	assert_output --partial "[echo] foo/bar/bar"
}

@test "should print test results when build failed for Concourse" {
	export BUILD_OPTIONS="invalid option"
	export CI="CONCOURSE"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
}

function findLatestProdTag {
    echo ""
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck" {
	export BUILD_OPTIONS="invalid option"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Concourse" {
	export CI="CONCOURSE"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
}

@test "should run the check when prod tag exists for apiCompatibilityCheck for Jenkins" {
	export CI="JENKINS"
	export LATEST_PROD_TAG="prod/100.0.0"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run apiCompatibilityCheck

	assert_output --partial "Last prod version equals [100.0.0]"
	assert_output --partial "[echo] 100.0.0"
}

@test "should print a property value from pom.xml if it exists" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run extractMavenProperty "foo.bar"

	assert_output "baz"
}

@test "should print empty string from pom.xml if it doesn't exist" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run extractMavenProperty "missing"

	assert_output ""
}

@test "should print group id from pom.xml" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveGroupId

	assert_output "com.example"
}

@test "should print artifact id from pom.xml" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveAppName

	assert_output "test"
}

@test "should print artifact id from pom.xml" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run printTestResults

	assert_output --partial "Build failed!!!"
}

@test "should print stubrunner ids property from pom.xml" {
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run retrieveStubRunnerIds

	assert_output --partial "foo.bar.baz"
}

@test "should run the smoke tests for Concourse" {
	export CI="CONCOURSE"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
}

@test "should run the smoke tests for Jenkins" {
	export CI="JENKINS"
	export APPLICATION_URL="foo"
	export STUBRUNNER_URL="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run runSmokeTests

	assert_output --partial "SMOKE TESTS [foo/bar]"
}

@test "should print test results when build failed for Jenkins" {
	export BUILD_OPTIONS="invalid option"
	export CI="JENKINS"
	export PIPELINE_VERSION="100.0.0"
	export M2_SETTINGS_REPO_ID="foo"
	export REPO_WITH_BINARIES="bar"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-maven.sh"

	run build

	assert_output --partial "Build failed!!!"
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

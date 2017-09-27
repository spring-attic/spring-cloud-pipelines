#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

function curl {
	local repo="${1}"
	if [[ "${repo}" == *failed* ]]; then
		return 1
	else
		return 0
	fi
}

export -f curl

@test "should return unknown if no matching project type is found" {
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "UNKNOWN"
}

@test "should return MAVEN if mvnw file is found" {
	touch "${PIPELINES_TEST_DIR}/mvnw"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "MAVEN"
}

@test "should return GRADLE if gradlew file is found" {
	touch "${PIPELINES_TEST_DIR}/gradlew"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "GRADLE"
}

@test "should return PROJECT_TYPE env var after sourcing" {
	touch "${PIPELINES_TEST_DIR}/gradlew"
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	assert_equal "${PROJECT_TYPE}" "GRADLE"
}

@test "should download an artifact if file hasn't been downloaded" {
	export OUTPUT_FOLDER="output"
	alias curl=curl_successfully
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "repoWithJars" "group.id" "artifactId" "version"

	assert_output --partial 'File downloaded successfully'
	assert_success
}

@test "should download a WAR artifact if file hasn't been downloaded" {
	export OUTPUT_FOLDER="output"
	export BINARY_EXTENSION="war"
	alias curl=curl_successfully
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "repoWithJars" "group.id" "artifactId" "version"

	assert_output --partial 'artifactId-version.war'
	assert_output --partial 'File downloaded successfully'
	assert_success
}

@test "should exit 1 when failed to download the artifact" {
	export OUTPUT_FOLDER="output"
	alias curl=curl_unsuccessfully
	source "${PIPELINES_TEST_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "failed" "group.id" "artifactId" "version"

	assert_output --partial 'Failed to download file!'
	assert_failure
}

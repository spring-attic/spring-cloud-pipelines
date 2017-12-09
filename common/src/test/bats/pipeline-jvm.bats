#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="dummy"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	mkdir -p "${TEMP_DIR}/project"
}

teardown() {
	rm -rf -- "${TEMP_DIR}" "${SOURCE_DIR}/pipeline-dummy.sh"
}

function curl {
	local repo="${@}"
	if [[ "${repo}" == *failed* ]]; then
		return 1
	else
		return 0
	fi
}

export -f curl

@test "should return unknown if no matching project type is found" {
	cd "/"
	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "UNKNOWN"
}

@test "should return MAVEN if mvnw file is found" {
	cd "${TEMP_DIR}/project" && touch mvnw

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "MAVEN"
}

@test "should return GRADLE if gradlew file is found" {
	cd "${TEMP_DIR}/project" && touch gradlew

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run projectType

	assert_output "GRADLE"
}

@test "should return PROJECT_TYPE env var after sourcing" {
	cd "${TEMP_DIR}/project" && touch gradlew

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	assert_equal "${PROJECT_TYPE}" "GRADLE"
}

@test "should download an artifact if file hasn't been downloaded" {
	export OUTPUT_FOLDER="${TEMP_DIR}/output"

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "repoWithJars" "group.id" "artifactId" "version"

	assert_output --partial 'File downloaded successfully'
	assert_success
}

@test "should download a WAR artifact if file hasn't been downloaded" {
	export OUTPUT_FOLDER="${TEMP_DIR}/output"
	export BINARY_EXTENSION="war"

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "repoWithJars" "group.id" "artifactId" "version"

	assert_output --partial 'artifactId-version.war'
	assert_output --partial 'File downloaded successfully'
	assert_success
}

@test "should exit 1 when failed to download the artifact" {
	export OUTPUT_FOLDER="${TEMP_DIR}/output"

	source "${SOURCE_DIR}/projectType/pipeline-jvm.sh"

	run downloadAppBinary "failed" "group.id" "artifactId" "version"

	assert_output --partial 'Failed to download file!'
	assert_failure
}

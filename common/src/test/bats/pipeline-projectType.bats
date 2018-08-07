#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
}

teardown() {
	rm -f "${SOURCE_DIR}/pipeline-dummy.sh"
	rm -rf "${TEMP_DIR}"
}

@test "should return language type from parsed descriptor" {
	PARSED_YAML='{"language_type":"foo"}'
	export LANGUAGE_TYPE=""
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(getLanguageType)"

	assert_equal "foo" "${result}"
	assert_equal "foo" "${LANGUAGE_TYPE}"
}

@test "should return empty when no descriptor is parsed" {
	LANGUAGE_TYPE=foo
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(getLanguageType)"

	assert_equal "" "${result}"
}

@test "should fail if no descriptor is parsed and no language type can be guessed or provided" {
	cd "${TEMP_DIR}"

	run "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	assert_failure
}

@test "should return empty when no language is present in parsed descriptor" {
	cd "${TEMP_DIR}"
	PARSED_YAML='{"foo":"foo"}'

	run "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	assert_failure
}

@test "should return php if composer.json is found" {
	cd "${TEMP_DIR}"
	touch "${TEMP_DIR}/composer.json"
	PIPELINE_DESCRIPTOR="foo.yml"
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(guessLanguageType)"

	assert_equal "php" "${result}"
	assert_equal "php" "${LANGUAGE_TYPE}"
}

@test "should return npm if package.json is found" {
	cd "${TEMP_DIR}"
	touch "${TEMP_DIR}/package.json"
	PIPELINE_DESCRIPTOR="foo.yml"
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(guessLanguageType)"

	assert_equal "npm" "${result}"
	assert_equal "npm" "${LANGUAGE_TYPE}"
}

@test "should return jvm if mvn is found" {
	touch "${TEMP_DIR}/mvnw"
	cd "${TEMP_DIR}"
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(guessLanguageType)"

	assert_equal "jvm" "${result}"
	assert_equal "jvm" "${LANGUAGE_TYPE}"
}

@test "should return jvm if gradlew is found" {
	touch "${TEMP_DIR}/gradlew"
	cd "${TEMP_DIR}"
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(guessLanguageType)"

	assert_equal "jvm" "${result}"
	assert_equal "jvm" "${LANGUAGE_TYPE}"
}

@test "should return dotnet if a .sln file is found" {
	touch "${TEMP_DIR}/foo.sln"
	cd "${TEMP_DIR}"
	source "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	result="$(guessLanguageType)"

	assert_equal "dotnet" "${result}"
	assert_equal "dotnet" "${LANGUAGE_TYPE}"
}

@test "should fail if no supported language is found" {
	cd "${TEMP_DIR}"

	run "${SOURCE_DIR}/projectType/pipeline-projectType.sh"

	assert_failure
}

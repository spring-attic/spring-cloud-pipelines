#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="test"
	export PAAS_TYPE="dummy"
	
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
}

teardown() {
	rm -f "${SOURCE_DIR}/pipeline-dummy.sh"
}

@test "toLowerCase should convert a string lower case" {
	source "${SOURCE_DIR}/pipeline.sh"

	run toLowerCase "Foo"
	assert_output "foo"

	run toLowerCase "FOObar"
	assert_output "foobar"
}

@test "yaml2json should convert valid YAML file to JSON" {
	source "${SOURCE_DIR}/pipeline.sh"

	run yaml2json "${FIXTURES_DIR}/sc-pipelines-generic.yml"

	assert_success
}

@test "yaml2json should fail with invalid YAML file" {
	source "${SOURCE_DIR}/pipeline.sh"

	run yaml2json "${FIXTURES_DIR}/pipeline-invalid.yml"

	assert_failure
}

@test "deployServices should deploy services from pipeline descriptor" {
	export PIPELINE_DESCRIPTOR="sc-pipelines-generic.yml"
	source "${SOURCE_DIR}/pipeline.sh"

	cd "${FIXTURES_DIR}"

	run deployServices

	assert_success
	assert_line --index 0 'rabbitmq-github-webhook broker'
	assert_line --index 1 'mysql-github-webhook broker'
	assert_line --index 2 'eureka-github-webhook app'
	assert_line --index 3 'stubrunner stubrunner'
}

@test "parsePipelineDescriptor should export an env var with parsed YAML" {
	source "${SOURCE_DIR}/pipeline.sh"
	
	PIPELINE_DESCRIPTOR="${FIXTURES_DIR}/sc-pipelines-generic.yml"

	assert_equal "${PARSED_YAML}" ""

	parsePipelineDescriptor

	assert_success
	assert [ "${PARSED_YAML}" != "${PARSED_YAML/\"coordinates\"/}" ]
}

@test "sourcing pipeline.sh should export an env var with lower case env var" {
	export ENVIRONMENT="FOO"

	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${ENVIRONMENT}" "FOO"
	assert_equal "${LOWERCASE_ENV}" "foo"
}

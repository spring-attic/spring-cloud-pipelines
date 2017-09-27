#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="test"
	export PAAS_TYPE="dummy"

	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"
}

@test "toLowerCase should convert a string lower case" {
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run toLowerCase "Foo"
	assert_output "foo"
	
	run toLowerCase "FOObar"
	assert_output "foobar"
}

@test "yaml2json should convert valid YAML file to JSON" {
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run yaml2json "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml"

	assert_success
}

@test "yaml2json should fail with invalid YAML file" {
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run yaml2json "${BATS_TEST_DIRNAME}/fixtures/pipeline-invalid.yml"

	assert_failure
}

@test "deployServices should deploy services from pipeline descriptor" {
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run deployServices

	assert_success
	assert_line --index 0 'rabbitmq rabbitmq-github-webhook null'
	assert_line --index 1 'mysql mysql-github-webhook null'
	assert_line --index 2 'eureka eureka-github-webhook com.example.eureka:github-eureka:0.0.1.M1'
	assert_line --index 3 'stubrunner stubrunner-github-webhook com.example.github:github-analytics-stub-runner-boot-classpath-stubs:0.0.1.M1'
}

@test "parsePipelineDescriptor should export an env var with parsed YAML" {
	source "${PIPELINES_TEST_DIR}/pipeline.sh"
    assert_equal "${PARSED_YAML}" ""

	parsePipelineDescriptor "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml"

	assert_success
	assert [ "${PARSED_YAML}" != "${PARSED_YAML/\"coordinates\"/}" ]
}

@test "sourcing pipeline.sh should export an env var with lower case env var" {
	export ENVIRONMENT="FOO"

	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	assert_equal "${ENVIRONMENT}" "FOO"
	assert_equal "${LOWERCASE_ENV}" "foo"
}

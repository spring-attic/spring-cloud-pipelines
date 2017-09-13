#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export ENVIRONMENT="test"
	export PAAS_TYPE="dummy"
}

@test "toLowerCase should convert a string lower case" {
	source "${BATS_TEST_DIRNAME}/../../main/bash/pipeline.sh"

	run toLowerCase "Foo"
	assert_output "foo"
	
    run toLowerCase "FOObar"
	assert_output "foobar"
}

@test "yaml2json should convert valid YAML file to JSON" {
	source "${BATS_TEST_DIRNAME}/../../main/bash/pipeline.sh"
	run yaml2json "${BATS_TEST_DIRNAME}/fixtures/pipeline.yml"
	assert_success
}

@test "yaml2json should fail with invalid YAML file" {
	source "${BATS_TEST_DIRNAME}/../../main/bash/pipeline.sh"
	run yaml2json "${BATS_TEST_DIRNAME}/fixtures/pipeline-invalid.yml"
	assert_failure
}

@test "deployServices should deploy services from pipeline descriptor" {
	source "${BATS_TEST_DIRNAME}/../../main/bash/pipeline.sh"

	cd "${BATS_TEST_DIRNAME}/fixtures" 

	run deployServices
	assert_success
	assert_line --index 0 'rabbitmq rabbitmq-github-webhook null'
	assert_line --index 1 'mysql mysql-github-webhook null'
	assert_line --index 2 'eureka eureka-github-webhook com.example.eureka:github-eureka:0.0.1.M1'
	assert_line --index 3 'stubrunner stubrunner-github-webhook com.example.github:github-analytics-stub-runner-boot-classpath-stubs:0.0.1.M1'
}

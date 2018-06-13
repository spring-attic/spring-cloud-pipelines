#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="test"
	export PAAS_TYPE="dummy"

	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	cp -a "${FIXTURES_DIR}/generic" "${TEMP_DIR}"
}

teardown() {
	rm -f "${SOURCE_DIR}/pipeline-dummy.sh"
	rm -rf "${TEMP_DIR}"
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
	assert_success
}

@test "should return SINGLE_REPO PROJECT_SETUP for a repo with no descriptor" {
	cd "${TEMP_DIR}/generic/single_repo_no_descriptor"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${PROJECT_SETUP}" "SINGLE_REPO"
	assert_output --partial "Pipeline descriptor missing"
	assert_success
}

@test "should return SINGLE_REPO PROJECT_SETUP for a repo with descriptor without coordinates" {
	cd "${TEMP_DIR}/generic/single_repo"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	refute_output --partial "Pipeline descriptor missing"
	assert_equal "${PROJECT_SETUP}" "SINGLE_REPO"
	assert_success
}

@test "should return MULTI_MODULE PROJECT_SETUP for a repo with descriptor with coordinates" {
	cd "${TEMP_DIR}/generic/multi_module"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	refute_output --partial "Pipeline descriptor missing"
	assert_equal "${PROJECT_SETUP}" "MULTI_MODULE"
	assert_success
}

@test "should return MULTI_PROJECT PROJECT_SETUP for a repo with no descriptor at root but with PROJECT_NAME dir existent with no descriptor" {
	cd "${TEMP_DIR}/generic/multi_project"
	export PROJECT_NAME="foo"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_output --partial "Pipeline descriptor missing"
	assert_equal "${PROJECT_SETUP}" "MULTI_PROJECT"
	assert_success
}

@test "should return MULTI_PROJECT PROJECT_SETUP for a repo with no descriptor at root but with PROJECT_NAME dir existent with descriptor with no build coordinates" {
	cd "${TEMP_DIR}/generic/multi_project"
	export PROJECT_NAME="bar"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_output --partial "Pipeline descriptor missing"
	assert_equal "${PROJECT_SETUP}" "MULTI_PROJECT"
	assert_success
}

@test "should return MULTI_PROJECT_WITH_MODULES PROJECT_SETUP for a repo with no descriptor at root but with PROJECT_NAME dir existent with descriptor with build coordinates" {
	cd "${TEMP_DIR}/generic/multi_project_with_modules"
	export PROJECT_NAME="foo"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_output --partial "Pipeline descriptor missing"
	assert_equal "${PROJECT_SETUP}" "MULTI_PROJECT_WITH_MODULES"
	assert_success
}

@test "should set PROJECT_NAME to 'single_repo_no_descriptor' for SINGLE_REPO project setup and PROJECT_NAME initially set to 'null'" {
	cd "${TEMP_DIR}/generic/single_repo_no_descriptor"
	export PROJECT_NAME="null"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${PROJECT_SETUP}" "SINGLE_REPO"
	assert_equal "${PROJECT_NAME}" "single_repo_no_descriptor"
	assert_success
}

@test "should set PROJECT_NAME to 'single_repo' when PROJECT_NAME initially set to 'null' for SINGLE_REPO PROJECT_SETUP for a repo with descriptor without coordinates" {
	cd "${TEMP_DIR}/generic/single_repo"
	export PROJECT_NAME="null"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${PROJECT_SETUP}" "SINGLE_REPO"
	assert_equal "${PROJECT_NAME}" "single_repo"
	assert_success
}

@test "should set PROJECT_NAME to 'multi_module' when PROJECT_NAME initially set to 'null' for MULTI_MODULE PROJECT_SETUP for a repo with descriptor with coordinates" {
	cd "${TEMP_DIR}/generic/multi_module"
	export PROJECT_NAME="null"

	# to get the output
	run "${SOURCE_DIR}/pipeline.sh"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${PROJECT_SETUP}" "MULTI_MODULE"
	assert_equal "${PROJECT_NAME}" "multi_module"
	assert_success
}

@test "should find the latest tag from git project for existant project name" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export PROJECT_NAME="app-monolith"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(latestProdTagFromGit)" "refs/tags/prod/app-monolith/1.0.0.M1-20180607_144049-VERSION"
	assert_success
}

@test "should return empty string if no tag is matching" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export PROJECT_NAME="non-existant"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(latestProdTagFromGit)" ""
	assert_success
}

@test "should return value of PASSED_LATEST_PROD_TAG if present" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export PASSED_LATEST_PROD_TAG="hello"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(findLatestProdTag)" "hello"
	assert_success
}

@test "should return value of LATEST_PROD_TAG if present" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export LATEST_PROD_TAG="hello"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(findLatestProdTag)" "hello"
	assert_success
}

@test "should return empty string if no tag is matching for production tag" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export PROJECT_NAME="non-existant"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(findLatestProdTag)" ""
	assert_success
}

@test "should return production tag if production tag is found" {
	cd "${TEMP_DIR}/generic/git_project"
	mv git .git
	export PROJECT_NAME="app-monolith"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(findLatestProdTag)" "prod/app-monolith/1.0.0.M1-20180607_144049-VERSION"
	assert_success
}

@test "should trim the refs tag from the parameter" {
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(trimRefsTag refs/tags/prod/app-monolith/1.0.0.M1-20180607_144049-VERSION)" "prod/app-monolith/1.0.0.M1-20180607_144049-VERSION"
	assert_success
}

@test "should return empty string if no YAML got parsed" {
	cd "${TEMP_DIR}/generic/single_repo_no_descriptor"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(getMainModulePath)" ""
	assert_success
}

@test "should return the main module path from parsed descriptor" {
	cd "${TEMP_DIR}/generic/multi_module"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(getMainModulePath)" "foo/bar"
	assert_success
}

@test "should return empty string if no main module section is present in the descriptor" {
	cd "${TEMP_DIR}/generic/single_repo"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "$(getMainModulePath)" ""
	assert_success
}

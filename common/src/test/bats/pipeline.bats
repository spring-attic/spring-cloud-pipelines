#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="test"
	export PAAS_TYPE="dummy"
	export LANGUAGE_TYPE="dummy"

	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}/projectType"
	cp -a "${FIXTURES_DIR}/generic" "${TEMP_DIR}"
	cp -a "${FIXTURES_DIR}/maven" "${TEMP_DIR}/maven"
	cp -a "${FIXTURES_DIR}/gradle" "${TEMP_DIR}/gradle"
	cp -a "${SOURCE_DIR}" "${TEMP_DIR}/sc-pipelines"
}

teardown() {
	rm -f "${SOURCE_DIR}/pipeline-dummy.sh"
	rm -f "${SOURCE_DIR}/projectType/pipeline-dummy.sh"
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

@test "parsePipelineDescriptor should not parse twice" {
	source "${SOURCE_DIR}/pipeline.sh"

	PIPELINE_DESCRIPTOR="${FIXTURES_DIR}/sc-pipelines-generic.yml"

	assert_equal "${PARSED_YAML}" ""

	parsePipelineDescriptor

	assert_success
	assert [ "${PARSED_YAML}" != "${PARSED_YAML/\"coordinates\"/}" ]

	run parsePipelineDescriptor

	assert_output --partial "Pipeline descriptor already parsed - will not parse it again"
	assert_success
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

@test "should return jvm language type for maven" {
	export LANGUAGE_TYPE=""
	cd "${TEMP_DIR}/maven/build_project"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "jvm"
	assert_success
}

@test "should return jvm language type for gradle" {
	export LANGUAGE_TYPE=""
	cd "${TEMP_DIR}/gradle/build_project"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "jvm"
	assert_success
}

@test "should return custom language type if provided explicitly and language is set in descriptor" {
	cd "${TEMP_DIR}/generic/php_repo"
	export LANGUAGE_TYPE=foo
	export PROJECT_NAME="php"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "foo"
	assert_success
}

@test "should return custom language type if set in descriptor" {
	cd "${TEMP_DIR}/generic/php_repo"
	export LANGUAGE_TYPE=""
	export PROJECT_NAME="php"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "php"
	assert_success
}

@test "should return php if composer is there" {
	cd "${TEMP_DIR}/generic/multi_module"
	export LANGUAGE_TYPE=""
	export PROJECT_NAME="php_project"
	touch "${TEMP_DIR}/generic/multi_module/composer.json"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "php"
	assert_success
}

@test "should return language type from descriptor" {
	cd "${TEMP_DIR}/generic/php_repo"
	export LANGUAGE_TYPE=""
	export PROJECT_NAME="php"

	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	assert_equal "${LANGUAGE_TYPE}" "php"
	assert_success
}

@test "should not break when deploy services is called and there are no services" {
	cd "${TEMP_DIR}/generic/php_repo"
	export PROJECT_NAME="php"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	run deployServices

	assert_success
}

@test "should fail if there is no environment node present" {
	cd "${TEMP_DIR}/generic/php_repo"
	export PROJECT_NAME="php"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	run envNodeExists "test"

	assert_failure
}

@test "should succeed if there is an environment node present" {
	cd "${TEMP_DIR}/generic/php_repo"
	export PROJECT_NAME="php"
	PIPELINE_DESCRIPTOR="${FIXTURES_DIR}/sc-pipelines-generic.yml"
	# to get the env vars
	source "${SOURCE_DIR}/pipeline.sh"

	run envNodeExists "test"

	assert_success
}

@test "should skip the step if prod tag is missing for apiCompatibilityCheck" {
	export BUILD_OPTIONS="invalid option"
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run apiCompatibilityCheck

	assert_output --partial "No prod release took place - skipping this step"
	assert_success
}

@test "should store versions in a file for apiCompatibilityCheck" {
	export BUILD_OPTIONS="invalid option"
	export PASSED_LATEST_PROD_TAG="prod/foo/1.0.0.RELEASE"
	export PROJECT_NAME=foo
	cd "${TEMP_DIR}/gradle/build_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run apiCompatibilityCheck

	refute_output --partial "No prod release took place - skipping this step"
	assert_success
	trigger="$( cat "target/trigger.properties" )"
	assert_equal "$( echo "${trigger}" | grep -w "LATEST_PROD_VERSION=1.0.0.RELEASE")" "LATEST_PROD_VERSION=1.0.0.RELEASE"
	assert_equal "$( echo "${trigger}" | grep -w "LATEST_PROD_TAG=prod/foo/1.0.0.RELEASE")" "LATEST_PROD_TAG=prod/foo/1.0.0.RELEASE"
	assert_equal "$( echo "${trigger}" | grep -w "PASSED_LATEST_PROD_TAG=prod/foo/1.0.0.RELEASE")" "PASSED_LATEST_PROD_TAG=prod/foo/1.0.0.RELEASE"
}

@test "should source a custom script if present" {
	export PAAS_TYPE=cf
	cd "${TEMP_DIR}/gradle/build_project"
	ln -s "${FIXTURES_DIR}/custom/build_and_upload.sh" "${TEMP_DIR}/sc-pipelines/custom/build_and_upload.sh"
	export CUSTOM_SCRIPT_NAME="build_and_upload.sh"
	source "${TEMP_DIR}/sc-pipelines/pipeline.sh"

	run build

	assert_output --partial "I am executing a custom build function"
	assert_success
}

@test "should source a custom PAAS script if present" {
	export PAAS_TYPE=cf
	cd "${TEMP_DIR}/gradle/build_project"
	ln -s "${FIXTURES_DIR}/custom/pipeline-cf.sh" "${TEMP_DIR}/sc-pipelines/custom/pipeline-cf.sh"
	source "${TEMP_DIR}/sc-pipelines/pipeline.sh"

	run logInToPaas

	assert_output --partial "I am executing a custom login function"
	assert_success
}

function stubbed_git() {
	echo "git $*"
}

@test "should delete prod tag" {
	export GIT_BIN="stubbed_git"
	source "${SOURCE_DIR}/pipeline.sh"
	export PIPELINE_VERSION="1.0.0"
	export PROJECT_NAME="foo"

	run removeProdTag
	assert_output --partial "git push --delete origin prod/${PROJECT_NAME}/${PIPELINE_VERSION}"
}

@test "should delete explicit prod tag" {
	export GIT_BIN="stubbed_git"
	source "${SOURCE_DIR}/pipeline.sh"
	export PIPELINE_VERSION="1.0.0"
	export PROJECT_NAME="foo"

	run removeProdTag "prod/bar/2.0.0"
	assert_output --partial "git push --delete origin prod/bar/2.0.0"
}

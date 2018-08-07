#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	export ENVIRONMENT="TEST"
	export PAAS_TYPE="dummy"
	ln -s "${FIXTURES_DIR}/pipeline-dummy.sh" "${SOURCE_DIR}"
	cp -a "${FIXTURES_DIR}/generic/" "${TEMP_DIR}"
}

teardown() {
	rm -f "${SOURCE_DIR}/pipeline-dummy.sh"
	rm -rf "${TEMP_DIR}"
}

function npm {
	if [[ "${2}" == "app-name" ]]; then
		echo "my-project"
	elif [[ "${2}" == "group-id" ]]; then
		echo "com.example"
	elif [[ "${2}" == "stub-ids" ]]; then
		echo "com.example:foo:1.0.0.RELEASE:stubs:1234"
	elif [[ "$*" == *"version"* ]]; then
		echo "1.0.0"
	else
		echo "npm $*"
	fi
}

function node {
	if [[ "$*" == *"version"* ]]; then
		echo "1.0.0"
	else
		echo "node $*"
	fi
}

function empty_npm {
	echo ""
}

function empty_node {
	return 1
}

function apt-get {
	echo "apt-get $*"
}

function sudo {
	echo "sudo $*"
}

function curl {
	echo "echo 'hello'"
}

@test "should build the project when npm and node are installed [Npm]" {
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	run build

	# App
	assert_output --partial "npm install"
	assert_output --partial "npm run test"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
	assert_success
	assert_equal "${DOWNLOADABLE_SOURCES}" ""
}

@test "should return fixed project name if differs from the default one [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="bar"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( retrieveAppName )" "foo"
	assert_success
}

@test "should call npm to get the app name if it's equal to the default one [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( retrieveAppName )" "my-project"
	assert_success
}

@test "should call npm to get the group id [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( retrieveGroupId )" "com.example"
	assert_success
}

@test "should call npm to get the stub runner ids [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( retrieveStubRunnerIds )" "com.example:foo:1.0.0.RELEASE:stubs:1234"
	assert_success
}

@test "should call run api-compatibility-check task [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( executeApiCompatibilityCheck )" "npm run test-apicompatibility"
	assert_success
}

@test "should call run smoke tests task [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( runSmokeTests )" "npm run test-smoke"
	assert_success
}

@test "should call run e2e task [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( runE2eTests )" "npm run test-e2e"
	assert_success
}

@test "should return NPM project type [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( projectType )" "NPM"
	assert_success
}

@test "should return target as output folder [Npm]" {
	export PROJECT_NAME="foo"
	export DEFAULT_PROJECT_NAME="foo"
	source "${SOURCE_DIR}/projectType/pipeline-npm.sh"

	assert_equal "$( outputFolder )" "target"
	assert_success
}

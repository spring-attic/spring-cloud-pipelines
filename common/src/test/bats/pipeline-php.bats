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

function composer {
	if [[ "${1}" == "app-name" ]]; then
		echo "my-project"
	elif [[ "${1}" == "group-id" ]]; then
		echo "com.example"
	elif [[ "$*" == *"version"* ]]; then
		echo "1.0.0"
	else
		echo "composer $*"
	fi
}

function php {
	if [[ "$*" == *"version"* ]]; then
		echo "1.0.0"
	else
		echo "php $*"
	fi
}

function apt-get {
	echo "apt-get $*"
}

function add-apt-repository {
	echo "add-apt-repository $*"
}

function tar {
	echo "tar $*"
}

function curl {
	echo "curl $*"
}

@test "should build the project when composer and php are installed [Composer]" {
	export PIPELINE_VERSION=1.0.0.M8
	export M2_SETTINGS_REPO_USERNAME="foo"
	export M2_SETTINGS_REPO_PASSWORD="bar"
	export REPO_WITH_BINARIES_FOR_UPLOAD="http://foo"
	source "${SOURCE_DIR}/projectType/pipeline-php.sh"

	run build

	# App
	assert_output --partial "composer install"
	assert_output --partial "tar -czf"
	assert_output --partial "curl -u foo:bar -X PUT http://foo/com/example/my-project/1.0.0.M8/my-project-1.0.0.M8.tar.gz --upload-file"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
	assert_success
}

#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	
	export MAVENW_BIN="mockMvnw"
	export GRADLEW_BIN="mockGradlew"

	export ENVIRONMENT="TEST"
	export PAAS_TYPE="CF"
	export REPO_WITH_BINARIES="http://foo"

	export PAAS_TEST_USERNAME="test-username"
	export PAAS_TEST_PASSWORD="test-password"
	export PAAS_TEST_ORG="test-org"
	export PAAS_TEST_SPACE="test-space"
	export PAAS_TEST_API_URL="test-api"

	cp -a "${FIXTURES_DIR}/gradle" "${FIXTURES_DIR}/maven" "${TEMP_DIR}"
}

teardown() {
	rm -rf -- "${TEMP_DIR}"
}

function curl {
	echo "curl $*"
}

function tar {
	echo "tar $*"
}

count=1
function cf_that_fails_first_time {
	if [[ "${1}" == "--version" && "${count}" == 1 ]]; then
		return 1
	else
		count=count+1
	fi
	echo "cf $*"
}

function cf_that_returns_apps {
	cat << EOF
Getting apps in org MyOrg / space sc-pipelines-prod as foo@bar...
OK

name                      requested state   instances   memory   disk   urls
github-analytics          started           1/1         1G       1G     github-analytics-sc-pipelines.demo.io
github-eureka             started           1/1         1G       1G     github-eureka-sc-pipelines-demo.demo.io, github-eureka-sc-pipelines.demo.io
github-webhook            started           1/1         1G       1G     github-webhook-sc-pipelines.demo.io
sc-pipelines-grafana      started           1/1         64M      1G     sc-pipelines-grafana.demo.io
sc-pipelines-prometheus   started           1/1         64M      1G     sc-pipelines-prometheus.demo.io
EOF
}

function cf_that_returns_test_apps {
	cat << EOF
Getting apps in org MyOrg / space sc-pipelines-prod as foo@bar...
OK

name                                 requested state   instances   memory   disk   urls
github-webhook                       started           1/1         1G       1G     github-webhook-sc-pipelines.demo.io
my-project                           started           1/1         1G       1G     my-project-sc-pipelines.demo.io
gradlew                              started           1/1         1G       1G     my-project-sc-pipelines.demo.io
eureka-github-webhook                started           1/1         1G       1G     eureka-github-webhook-sc-pipelines.demo.io
stubrunner-my-project                started           1/1         1G       1G     stubrunner-my-project-sc-pipelines.demo.io
stubrunner-gradlew                   started           1/1         1G       1G     stubrunner-my-project-sc-pipelines.demo.io
stubrunner-github-webhook            started           1/1         1G       1G     stubrunner-github-webhook-sc-pipelines.demo.io
EOF
}

function cf {
	if [[ "${1}" == "apps" ]]; then
		cf_that_returns_${LOWERCASE_ENV}_apps
		return
	fi
	echo "cf $*"
}

function mockMvnw {
	echo "mvnw $*"
}

function mockGradlew {
	echo "gradlew $*"
}

export -f curl
export -f tar
export -f cf
export -f cf_that_returns_apps
export -f cf_that_returns_test_apps
export -f cf_that_fails_first_time
export -f mockMvnw
export -f mockGradlew

@test "should download cf if it's missing and connect to cluster [CF]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf_that_fails_first_time"
	env="test"
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert_output --partial "CLI Installed? [false], CLI Downloaded? [false]"
	assert_output --partial "Downloading Cloud Foundry CLI"
	assert_output --partial "Adding CF to PATH"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
}

@test "should redownload cf if redownload infra flag is set and connect to cluster [CF]" {
	export REDOWNLOAD_INFRA="true"
	export CF_BIN="cf_that_fails_first_time"
	env="test"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${CF_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert_output --partial "CLI Installed? [false], CLI Downloaded? [true]"
	refute_output --partial "Downloading Cloud Foundry CLI"
	assert_output --partial "Adding CF to PATH"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
}

@test "should not redownload cf if redownload infra flag is not set and cf was downloaded and connect to cluster [CF]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf"
	env="test"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${CF_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert_output --partial "CLI Installed? [cf --version], CLI Downloaded? [true]"
	refute_output --partial "Downloading Cloud Foundry CLI"
	assert_output --partial "Adding CF to PATH"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
}

@test "should retrieve the host from the URL from CF [CF]" {
	export CF_BIN="cf_that_returns_apps"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${CF_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	result="$( appHost "github-analytics" )"
	assert_equal "${result}" "github-analytics-sc-pipelines.demo.io"

	result="$( appHost "github-eureka" )"
	assert_equal "${result}" "github-eureka-sc-pipelines-demo.demo.io"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing [CF][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "${CF_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f my-project"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart my-project"
}

@test "should deploy app to test environment with additional services [CF][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .
	touch "${CF_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f my-project"
	# Deletion of services
	assert_output --partial "cf delete -f rabbitmq-github-webhook"
	assert_output --partial "cf delete-service -f rabbitmq-github-webhook"
	assert_output --partial "cf cs cloudamqp lemur rabbitmq-github-webhook"
	assert_output --partial "cf delete -f mysql-github-webhook"
	assert_output --partial "cf delete-service -f mysql-github-webhook"
	assert_output --partial "cf cs p-mysql 100mb mysql-github-webhook"
	# Pushing services
	# Eureka
	assert_output --partial "cf delete -f eureka-github-webhook"
	assert_output --partial "cf delete-service -f eureka-github-webhook"
	assert_output --partial "cf push eureka-github-webhook"
	assert_output --partial "cf set-env eureka-github-webhook APPLICATION_DOMAIN eureka-github-webhook-sc-pipelines.demo.io"
	assert_output --partial "cf set-env eureka-github-webhook JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial 'cf create-user-provided-service eureka-github-webhook -p {"uri":"http://eureka-github-webhook-sc-pipelines.demo.io"}'
	# Stub Runner
	assert_output --partial "cf delete -f stubrunner-github-webhook"
	assert_output --partial "cf delete-service -f stubrunner-github-webhook"
	assert_output --partial "cf push stubrunner-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook APPLICATION_DOMAIN stubrunner-github-webhook-sc-pipelines.demo.io"
	assert_output --partial "cf set-env stubrunner-github-webhook JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart stubrunner-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook stubrunner.ids"
	assert_output --partial "cf bind-service stubrunner-github-webhook rabbitmq-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook spring.rabbitmq.addresses"
	assert_output --partial "cf bind-service stubrunner-github-webhook eureka-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook eureka.client.serviceUrl.defaultZone"
	assert_output --partial "cf restart stubrunner-github-webhook"
	# App
	assert_output --partial "cf delete -f my-project"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN my-project-sc-pipelines.demo.io"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL=stubrunner-my-project-sc-pipelines.demo.io"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing [CF][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "${CF_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f ${projectName}"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service ${projectName} rabbitmq-${projectName}"
	refute_output --partial "cf bind-service ${projectName} eureka-${projectName}"
	refute_output --partial "cf bind-service ${projectName} mysql-${projectName}"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart gradlew artifactId -q"
}

@test "should deploy app to test environment with additional services [CF][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .
	touch "${CF_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f ${projectName}"
	# Deletion of services
	assert_output --partial "cf delete -f rabbitmq-github-webhook"
	assert_output --partial "cf delete-service -f rabbitmq-github-webhook"
	assert_output --partial "cf cs cloudamqp lemur rabbitmq-github-webhook"
	assert_output --partial "cf delete -f mysql-github-webhook"
	assert_output --partial "cf delete-service -f mysql-github-webhook"
	assert_output --partial "cf cs p-mysql 100mb mysql-github-webhook"
	# Pushing services
	# Eureka
	assert_output --partial "cf delete -f eureka-github-webhook"
	assert_output --partial "cf delete-service -f eureka-github-webhook"
	assert_output --partial "cf push eureka-github-webhook"
	assert_output --partial "cf set-env eureka-github-webhook APPLICATION_DOMAIN eureka-github-webhook-sc-pipelines.demo.io"
	assert_output --partial "cf set-env eureka-github-webhook JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial 'cf create-user-provided-service eureka-github-webhook -p {"uri":"http://eureka-github-webhook-sc-pipelines.demo.io"}'
	# Stub Runner
	assert_output --partial "cf delete -f stubrunner-github-webhook"
	assert_output --partial "cf delete-service -f stubrunner-github-webhook"
	assert_output --partial "cf push stubrunner-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook APPLICATION_DOMAIN stubrunner-github-webhook-sc-pipelines.demo.io"
	assert_output --partial "cf set-env stubrunner-github-webhook JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart stubrunner-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook stubrunner.ids"
	assert_output --partial "cf bind-service stubrunner-github-webhook rabbitmq-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook spring.rabbitmq.addresses"
	assert_output --partial "cf bind-service stubrunner-github-webhook eureka-github-webhook"
	assert_output --partial "cf set-env stubrunner-github-webhook eureka.client.serviceUrl.defaultZone"
	assert_output --partial "cf restart stubrunner-github-webhook"
	# App
	assert_output --partial "cf delete -f ${projectName}"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart gradlew artifactId -q"
	assert_output --partial "APPLICATION_URL="
	assert_output --partial "STUBRUNNER_URL="
}

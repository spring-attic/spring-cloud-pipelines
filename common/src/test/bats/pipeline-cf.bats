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

	export PAAS_STAGE_USERNAME="stage-username"
	export PAAS_STAGE_PASSWORD="stage-password"
	export PAAS_STAGE_ORG="stage-org"
	export PAAS_STAGE_SPACE="stage-space"
	export PAAS_STAGE_API_URL="stage-api"

	export PAAS_PROD_USERNAME="prod-username"
	export PAAS_PROD_PASSWORD="prod-password"
	export PAAS_PROD_ORG="prod-org"
	export PAAS_PROD_SPACE="prod-space"
	export PAAS_PROD_API_URL="prod-api"

	cp -a "${FIXTURES_DIR}/gradle" "${FIXTURES_DIR}/maven" "${TEMP_DIR}"
}

teardown() {
	rm -rf -- "${TEMP_DIR}"
}

function curl {
	echo "curl $*"
}

function tar {
	touch "${CF_BIN}"
	echo "tar $*"
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
Getting apps in org MyOrg / space sc-pipelines-test as foo@bar...
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

function cf_that_returns_stage_apps {
	cat << EOF
Getting apps in org MyOrg / space sc-pipelines-stage as foo@bar...
OK

name                                 requested state   instances   memory   disk   urls
github-webhook                       started           1/1         1G       1G     github-webhook-sc-pipelines.demo.io
my-project                           started           1/1         1G       1G     my-project-sc-pipelines.demo.io
gradlew                              started           1/1         1G       1G     my-project-sc-pipelines.demo.io
github-eureka                        started           1/1         1G       1G     github-eureka-sc-pipelines.demo.io
EOF
}

function cf_that_returns_prod_apps {
	cf_that_returns_apps
}

function cf_that_returns_nothing {
	if [[ "${1}" == "app" || "${1}" == "service" ]]; then
		return 1
	fi
	echo "cf $*"
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
export -f cf_that_returns_stage_apps
export -f cf_that_returns_prod_apps
export -f cf_that_returns_nothing
export -f mockMvnw
export -f mockGradlew

@test "should download cf and connect to cluster [CF]" {
	export CF_BIN="cf"
	env="test"
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert_output --partial "Downloading Cloud Foundry CLI"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_success
}

@test "should retrieve the host from the URL from CF [CF]" {
	export CF_BIN="cf_that_returns_apps"
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	result="$( appHost "github-analytics" )"
	assert_equal "${result}" "github-analytics-sc-pipelines.demo.io"

	result="$( appHost "github-eureka" )"
	assert_equal "${result}" "github-eureka-sc-pipelines-demo.demo.io"
	assert_success
}

@test "should bind a service only if it's already running [CF]" {
	export CF_BIN="cf_that_returns_nothing"
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run bindService "github-analytics"
	assert_output --partial "Service is not there"
	refute_output --partial "cf_that_returns_nothing bind-service"
	assert_success
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

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
	assert_success
}

@test "should deploy app to test environment with additional services [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

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
	assert_success
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

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
	assert_success
}

@test "should deploy app to test environment with additional services [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

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
	assert_success
}

@test "should prepare and execute smoke tests [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "mvnw clean install -Psmoke -Dapplication.url=my-project-sc-pipelines.demo.io -Dstubrunner.url=stubrunner-my-project-sc-pipelines.demo.io -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should prepare and execute smoke tests [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "gradlew artifactId -q"
	assert_output --partial "stubrunner-gradlew artifactId -q"
	assert_output --partial "gradlew smoke -PnewVersion= -Dapplication.url= -Dstubrunner.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should skip rollback deploy step if there are no tags [CF]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG=""
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "No prod release took place - skipping this step"
	assert_success
}

@test "should deploy app to test environment for rollback testing [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project/"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f my-project"
	assert_output --partial "cf delete -f my-project"
	assert_output --partial "cf bind-service my-project rabbitmq-github-webhook"
	assert_output --partial "cf bind-service my-project eureka-github-webhook"
	assert_output --partial "cf bind-service my-project mysql-github-webhook"
	assert_output --partial "cf bind-service my-project stubrunner-github-webhook"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN my-project-sc-pipelines.demo.io"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL=stubrunner-my-project-sc-pipelines.demo.io"
	assert_success
}

@test "should deploy app to test environment for rollback testing [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project/"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf delete -f ${projectName}"
	assert_output --partial "cf delete -f ${projectName}"
	assert_output --partial "cf bind-service gradlew artifactId -q rabbitmq-github-webhook"
	assert_output --partial "cf bind-service gradlew artifactId -q eureka-github-webhook"
	assert_output --partial "cf bind-service gradlew artifactId -q mysql-github-webhook"
	assert_output --partial "cf bind-service gradlew artifactId -q stubrunner-github-webhook"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,smoke"
	assert_output --partial "cf restart gradlew artifactId -q"
	assert_output --partial "APPLICATION_URL="
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should skip rollback testing step if there are no tags [CF]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG=""
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "No prod release took place - skipping this step"
	assert_success
}

@test "should prepare and execute rollback tests [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "mvnw clean install -Psmoke -Dapplication.url=my-project-sc-pipelines.demo.io -Dstubrunner.url=stubrunner-my-project-sc-pipelines.demo.io -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should prepare and execute rollback tests [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "gradlew artifactId -q"
	assert_output --partial "stubrunner-gradlew artifactId -q"
	assert_output --partial "gradlew smoke -PnewVersion= -Dapplication.url= -Dstubrunner.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should deploy app to stage environment without additional services if pipeline descriptor is missing [CF][Maven]" {
	export ENVIRONMENT="stage"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="stage"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart my-project"
	assert_success
}

@test "should deploy app to stage environment with additional services [CF][Maven]" {
	export ENVIRONMENT="stage"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="stage"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	# Deletion of services
	refute_output --partial "cf delete -f github-rabbitmq"
	refute_output --partial "cf delete-service -f github-rabbitmq"
	assert_output --partial "cf cs cloudamqp lemur github-rabbitmq"
	refute_output --partial "cf delete -f mysql-github"
	refute_output --partial "cf delete-service -f mysql-github"
	assert_output --partial "cf cs p-mysql 100mb mysql-github"
	# Pushing services
	# Eureka
	refute_output --partial "cf delete -f github-eureka"
	refute_output --partial "cf delete-service -f github-eureka"
	assert_output --partial "cf push github-eureka"
	assert_output --partial "cf set-env github-eureka APPLICATION_DOMAIN github-eureka-sc-pipelines.demo.io"
	assert_output --partial "cf set-env github-eureka JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart github-eureka"
	assert_output --partial 'cf create-user-provided-service github-eureka -p {"uri":"http://github-eureka-sc-pipelines.demo.io"}'
	# App
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN my-project-sc-pipelines.demo.io"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should deploy app to stage environment without additional services if pipeline descriptor is missing [CF][Gradle]" {
	export ENVIRONMENT="STAGE"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="stage"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service ${projectName} rabbitmq-${projectName}"
	refute_output --partial "cf bind-service ${projectName} eureka-${projectName}"
	refute_output --partial "cf bind-service ${projectName} mysql-${projectName}"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart gradlew artifactId -q"
	assert_success
}

@test "should deploy app to stage environment with additional services [CF][Gradle]" {
	export ENVIRONMENT="STAGE"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="stage"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" .

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	# Deletion of services
	refute_output --partial "cf delete -f github-rabbitmq"
	refute_output --partial "cf delete-service -f github-rabbitmq"
	assert_output --partial "cf cs cloudamqp lemur github-rabbitmq"
	refute_output --partial "cf delete -f mysql-github"
	refute_output --partial "cf delete-service -f mysql-github"
	assert_output --partial "cf cs p-mysql 100mb mysql-github"
	# Pushing services
	# Eureka
	refute_output --partial "cf delete -f github-eureka"
	refute_output --partial "cf delete-service -f github-eureka"
	assert_output --partial "cf push github-eureka"
	assert_output --partial "cf set-env github-eureka APPLICATION_DOMAIN github-eureka-sc-pipelines.demo.io"
	assert_output --partial "cf set-env github-eureka JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	assert_output --partial "cf restart github-eureka"
	assert_output --partial 'cf create-user-provided-service github-eureka -p {"uri":"http://github-eureka-sc-pipelines.demo.io"}'
	# App
	refute_output --partial "cf delete -f ${projectName}"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	# We don't want exception on jq parsing
	refute_output --partial "jq: error (at <stdin>:42): Cannot iterate over null (null)"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart gradlew artifactId -q"
	assert_output --partial "APPLICATION_URL="
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should prepare and execute e2e tests [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="stage"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "mvnw clean install -Pe2e -Dapplication.url=my-project-sc-pipelines.demo.io -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should prepare and execute e2e tests [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="stage"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "gradlew e2e -PnewVersion= -Dapplication.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should deploy app to prod environment [CF][Maven]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="prod"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push my-project"
	assert_output --partial "cf set-env my-project APPLICATION_DOMAIN"
	assert_output --partial "cf set-env my-project JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf set-env my-project spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart my-project"
	assert_success
}

@test "should deploy app to prod environment without additional services if pipeline descriptor is missing [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push ${projectName}"
	assert_output --partial "cf set-env ${projectName} APPLICATION_DOMAIN"
	assert_output --partial "cf set-env ${projectName} JAVA_OPTS -Djava.security.egd=file:///dev/urandom"
	refute_output --partial "cf bind-service ${projectName} rabbitmq-${projectName}"
	refute_output --partial "cf bind-service ${projectName} eureka-${projectName}"
	refute_output --partial "cf bind-service ${projectName} mysql-${projectName}"
	assert_output --partial "cf set-env ${projectName} spring.profiles.active cloud,e2e"
	assert_output --partial "cf restart gradlew artifactId -q"
	assert_success
}

@test "should complete switch over on prod [CF][Maven]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="prod"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "cf app my-project-venerable"
	assert_output --partial "cf delete my-project-venerable -f"
	assert_success
}

@test "should complete switch over on prod [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	projectName="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "cf app ${projectName}-venerable"
	assert_output --partial "cf delete ${projectName}-venerable -f"
	assert_success
}

@test "should complete switch over on prod without doing anything if app is missing [CF][Maven]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf_that_returns_nothing"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="prod"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "cf"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "Will not remove the old application cause it's not there"
	refute_output --partial "cf app my-project-venerable"
	refute_output --partial "cf delete -f my-project-venerable"
	assert_success
}

@test "should complete switch over on prod without doing anything if app is missing [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf_that_returns_nothing"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	projectName="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "cf"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "Will not remove the old application cause it's not there"
	refute_output --partial "cf app ${projectName}-venerable"
	refute_output --partial "cf delete ${projectName}-venerable -f"
	assert_success
}

@test "should rollback to blue instance on prod [CF][Maven]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="prod"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "cf app my-project-venerable"
	assert_output --partial "cf start my-project-venerable"
	assert_output --partial "cf stop my-project"
	assert_success
}

@test "should rollback to blue instance on prod [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	projectName="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "cf app ${projectName}-venerable"
	assert_output --partial "cf start ${projectName}-venerable"
	assert_output --partial "cf stop ${projectName}"
	assert_success
}

@test "should not rollback to blue if blue is missing [CF][Maven]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf_that_returns_nothing"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="prod"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "cf"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "Will not rollback to blue instance cause it's not there"
	refute_output --partial "cf start my-project-venerable"
	refute_output --partial "cf stop my-project"
	assert_failure
}

@test "should not rollback to blue if blue is missing [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf_that_returns_nothing"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	projectName="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	touch "cf"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "Will not rollback to blue instance cause it's not there"
	refute_output --partial "cf start ${projectName}-venerable"
	refute_output --partial "cf stop ${projectName}"
	assert_failure
}

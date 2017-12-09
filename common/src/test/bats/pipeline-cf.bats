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
	export PAAS_TEST_SPACE_PREFIX="test-space"
	export PAAS_TEST_API_URL="test-api"
	export RETRIEVE_STUBRUNNER_IDS_FUNCTION="fakeRetrieveStubRunnerIds"

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

function git {
	echo "git $*"
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
stubrunner                           started           1/1         1G       1G     stubrunner-my-project-sc-pipelines.demo.io
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
	elif [[ "${1}" == "routes" ]]; then
		cat << EOF
Getting routes for org FrameworksAndRuntimes / space test-my-project as mgrzejszczak@pivotal.io ...

space            host                                                  domain          port   path   type   apps               service
test-my-project  github-eureka-test-my-project                         cfapps.io                            github-eureka
test-my-project  stubrunner-test-my-project                            cfapps.io                            stubrunner
test-my-project  stubrunner-test-gradlew artifactId -q                 cfapps.io                            stubrunner
test-my-project  stubrunner-test-my-project-10000                      micrometer.io                        stubrunner
test-my-project  my-project-test                                       cfapps.io                            github-analytics
EOF
		return
	elif [[ "$*" == *"/v2/apps?q=name"* ]]; then
		echo '{ "resources": [ { "metadata" : { "guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be" } } ] }'
		return
	elif [[ "$*" == *"/v2/routes?q=host"* ]]; then
		echo '{ "resources": [ { "metadata" : { "guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be" } } ] }'
		return
	else
		echo "cf $*"
		return
	fi
}

function mockMvnw {
	echo "mvnw $*"
}

function mockGradlew {
	echo "gradlew $*"
}

function fakeRetrieveStubRunnerIds() {
	echo "a:a:version:classifier:10000,b:b:version:classifier:10001,c:c:version:classifier:10002"
}

export -f curl
export -f git
export -f tar
export -f cf
export -f cf_that_returns_apps
export -f cf_that_returns_test_apps
export -f cf_that_returns_stage_apps
export -f cf_that_returns_prod_apps
export -f cf_that_returns_nothing
export -f mockMvnw
export -f mockGradlew
export -f fakeRetrieveStubRunnerIds

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

	result="$( getAppHostFromPaas "github-analytics" )"
	assert_equal "${result}" "github-analytics-sc-pipelines.demo.io"

	result="$( getAppHostFromPaas "github-eureka" )"
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

@test "should fail to deploy app to test environment without additional services if manifest is missing [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	rm manifest.yml

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	assert_output --partial "App manifest.yml file not found"
	assert_failure
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	assert_output --partial "cf install-plugin do-all -r CF-Community -f"
	assert_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf push my-project"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should deploy app to test environment with additional services [CF][Maven]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export M2_SETTINGS_REPO_USERNAME="foo"
	export M2_SETTINGS_REPO_PASSWORD="bar"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	assert_output --partial "cf create-service foo bar mysql-github-webhook"
	assert_output --partial "cf push eureka-github-webhook -f manifest.yml -p target/github-eureka-0.0.1.M1.jar -n eureka-github-webhook-${env}-my-project -i 1 --no-start"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial "cf cups eureka-github-webhook -p"
	# Stub Runner
	assert_output --partial "Setting env var [APPLICATION_HOSTNAME] -> [stubrunner-test-my-project] for app [stubrunner]"
	assert_output --partial "Setting env var [APPLICATION_DOMAIN] -> [cfapps.io] for app [stubrunner]"
	assert_output --partial "curl -u foo:bar http://foo/com/example/github/github-analytics-stub-runner-boot-classpath-stubs/0.0.1.M1/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -o"
	assert_output --partial "cf curl /v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be -X PUT"
	assert_output --partial "[8080,10000,10001,10002"
	assert_output --partial "cf create-route test-space-my-project cfapps.io --hostname stubrunner-test-my-project-10000"
	assert_output --partial "cf curl /v2/route_mappings -X POST -d"
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10000'
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10001'
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10002'
	assert_output --partial "cf push stubrunner -f foo/manifest.yml -p target/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -n stubrunner-${env}-my-project -i 1 --no-start"
	assert_output --partial "cf set-env stubrunner stubrunner.ids"
	assert_output --partial "cf restart stubrunner"
	# App
	assert_output --partial "cf push my-project -f manifest.yml -p target/my-project-.jar -n my-project-${env} -i 1 --no-start"
	assert_output --partial "cf set-env my-project SPRING_PROFILES_ACTIVE cloud,smoke,test"
	assert_output --partial "cf restart my-project"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
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
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-${projectNameUppercase}"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-.jar -n ${projectName}-${env} -i 1 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,smoke,test"
	assert_output --partial "cf restart ${projectNameUppercase}"
	assert_success
}

@test "should deploy app to test environment with additional services [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export M2_SETTINGS_REPO_USERNAME="foo"
	export M2_SETTINGS_REPO_PASSWORD="bar"
	env="test"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-${projectNameUppercase}"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	assert_output --partial "cf create-service foo bar mysql-github-webhook"
	assert_output --partial "cf push eureka-github-webhook -f manifest.yml -p build/libs/github-eureka-0.0.1.M1.jar -n eureka-github-webhook-${env}-${projectNameUppercase} -i 1 --no-start"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial "cf cups eureka-github-webhook -p"
	# Stub Runner
	assert_output --partial "Setting env var [APPLICATION_HOSTNAME] -> [stubrunner-test-${projectNameUppercase}] for app [stubrunner]"
	assert_output --partial "Setting env var [APPLICATION_DOMAIN] -> [artifactId] for app [stubrunner]"
	assert_output --partial "curl -u foo:bar http://foo/com/example/github/github-analytics-stub-runner-boot-classpath-stubs/0.0.1.M1/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -o"
	assert_output --partial "cf curl /v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be -X PUT"
	assert_output --partial "[8080,10000,10001,10002"
	assert_output --partial "cf create-route test-space-${projectNameUppercase} artifactId --hostname stubrunner-test-${projectNameUppercase}-10000"
	assert_output --partial "cf curl /v2/route_mappings -X POST -d"
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10000'
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10001'
	assert_output --partial '"app_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "route_guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be", "app_port": 10002'
	assert_output --partial "cf push stubrunner -f foo/manifest.yml -p build/libs/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -n stubrunner-test-${projectNameUppercase} -i 1 --no-start"
	assert_output --partial "cf set-env stubrunner stubrunner.ids"
	assert_output --partial "cf restart stubrunner"
	# App
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-.jar -n ${projectName}-${env} -i 1 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,smoke,test"
	assert_output --partial "cf restart ${projectNameUppercase}"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	assert_output --partial "mvnw clean install -Psmoke -Dapplication.url=my-project-sc-pipelines.demo.io -Dstubrunner.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should prepare and execute smoke tests [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="test"
	projectName="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-${projectName}"
	assert_output --partial "gradlew artifactId -q"
	assert_output --partial "gradlew smoke -PnewVersion= -Dapplication.url= -Dstubrunner.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should skip rollback deploy step if there are no tags [CF]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG=""
	export GIT_BIN="echo 'master'"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

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
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project/sc-pipelines.yml"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	assert_output --partial "cf delete -f -r my-project"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	refute_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	refute_output --partial "cf cups eureka-github-webhook -p"
	refute_output --partial "cf restart stubrunner-github-webhook"
	# App
	assert_output --partial "cf push my-project -f manifest.yml -p target/my-project-1.0.0.FOO.jar -n my-project-${env} -i 1 --no-start"
	assert_output --partial "cf set-env my-project SPRING_PROFILES_ACTIVE cloud,smoke,test"
	assert_output --partial "cf restart my-project"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
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
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project/sc-pipelines.yml"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-${projectNameUppercase}"
	assert_output --partial "cf delete -f -r ${projectName}"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	refute_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	refute_output --partial "cf cups eureka-github-webhook -p"
	refute_output --partial "cf restart stubrunner-github-webhook"
	# App
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-1.0.0.FOO.jar -n ${projectName}-${env} -i 1 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,smoke,test"
	assert_output --partial "cf restart ${projectNameUppercase}"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
	assert_output --partial "APPLICATION_URL="
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should skip rollback testing step if there are no tags [CF]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG=""
	export GIT_BIN="echo ''"
	env="test"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

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
	assert_output --partial "git checkout prod/1.0.0.FOO"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-my-project"
	assert_output --partial "mvnw clean install -Psmoke -Dapplication.url=my-project-sc-pipelines.demo.io -Dstubrunner.url= -Djava.security.egd=file:///dev/urandom"
	assert_success
}

@test "should prepare and execute rollback tests [CF][Gradle]" {
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	env="test"
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "git checkout prod/1.0.0.FOO"
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space-${projectNameUppercase}"
	assert_output --partial "gradlew artifactId -q"
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
	refute_output --partial "cf create-space"
	refute_output --partial "cf install-plugin do-all -r CF-Community -f"
	refute_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf push my-project"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL="
	assert_success
}

@test "should deploy app to stage environment with additional services [CF][Maven]" {
	export ENVIRONMENT="stage"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	env="stage"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	refute_output --partial "cf create-space"
	refute_output --partial "cf install-plugin do-all -r CF-Community -f"
	refute_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar github-rabbitmq"
	assert_output --partial "cf create-service foo bar mysql-github"
	assert_output --partial "cf push github-eureka -f manifest.yml -p target/github-eureka-0.0.1.M1.jar -n github-eureka-${env} -i 1 --no-start"
	assert_output --partial "cf restart github-eureka"
	assert_output --partial "cf cups github-eureka -p"
	refute_output --partial "cf restart stubrunner"
	# App
	assert_output --partial "cf push my-project -f manifest.yml -p target/my-project-.jar -n my-project-${env} -i 2 --no-start"
	assert_output --partial "cf set-env my-project SPRING_PROFILES_ACTIVE cloud,e2e,stage"
	assert_output --partial "cf restart my-project"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
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
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	refute_output --partial "cf create-space"
	refute_output --partial "cf install-plugin do-all -r CF-Community -f"
	refute_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-.jar -n ${projectName}-${env} -i 2 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,e2e,stage"
	assert_output --partial "cf restart ${projectNameUppercase}"
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
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"
	cp "${FIXTURES_DIR}/sc-pipelines-cf.yml" sc-pipelines.yml

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	refute_output --partial "cf create-space"
	refute_output --partial "cf install-plugin do-all -r CF-Community -f"
	refute_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar github-rabbitmq"
	assert_output --partial "cf create-service foo bar mysql-github"
	assert_output --partial "cf push github-eureka -f manifest.yml -p build/libs/github-eureka-0.0.1.M1.jar -n github-eureka-${env} -i 1 --no-start"
	assert_output --partial "cf restart github-eureka"
	assert_output --partial "cf cups github-eureka -p"
	refute_output --partial "cf restart stubrunner"
	# App
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-.jar -n ${projectName}-${env} -i 2 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,e2e,stage"
	assert_output --partial "cf restart ${projectNameUppercase}"
	# We don't want exception on jq parsing
	refute_output --partial "Cannot iterate over null (null)"
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
	assert_output --partial "cf push my-project -f manifest.yml -p target/my-project-.jar -n my-project -i 2 --no-start"
	assert_output --partial "cf set-env my-project SPRING_PROFILES_ACTIVE cloud,prod"
	assert_output --partial "cf restart my-project"
	assert_success
}

@test "should deploy app to prod environment [CF][Gradle]" {
	export ENVIRONMENT="PROD"
	export CF_BIN="cf"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	env="prod"
	# notice lowercase of artifactid (should be artifactId) - but lowercase function gets applied
	projectName="gradlew artifactid -q"
	projectNameUppercase="gradlew artifactId -q"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/build_project"

	run "${SOURCE_DIR}/prod_deploy.sh"

	# logged in
	assert_output --partial "cf api --skip-ssl-validation ${env}-api"
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	refute_output --partial "cf delete -f my-project"
	assert_output --partial "cf push ${projectName} -f manifest.yml -p build/libs/${projectNameUppercase}-.jar -n ${projectName} -i 2 --no-start"
	assert_output --partial "cf set-env ${projectName} SPRING_PROFILES_ACTIVE cloud,prod"
	assert_output --partial "cf restart ${projectNameUppercase}"
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
	assert_output --partial "cf stop my-project-venerable"
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
	assert_output --partial "cf stop ${projectName}-venerable"
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
	assert_output --partial "Will not stop the old application cause it's not there"
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
	assert_output --partial "Will not stop the old application cause it's not there"
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

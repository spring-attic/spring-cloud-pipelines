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
	elif [[ "${1}" == "routes" ]]; then
		cat << EOF
Getting routes for org S1Pdemo12 / space cyi-scp-test-greeting-ui as mgrzejszczak@pivotal.io ...

space                      host                        domain      port   path   type   apps          service
cyi-scp-test-greeting-ui   stubrunner                  cfapps.io                        stubrunner
cyi-scp-test-greeting-ui   greeting-ui-cyi-test        cfapps.io                        greeting-ui
cyi-scp-test-greeting-ui   stubrunner-cyi-test-10000   cfapps.io                        stubrunner
cyi-scp-test-greeting-ui   stubrunner-cyi-test-10001   cfapps.io                        stubrunner
cyi-scp-test-greeting-ui   stubrunner-cyi-test-10002   cfapps.io                        stubrunner
EOF
		return
	elif [[ "$*" == *"/v2/apps?q=name"* ]]; then
		cat << EOF
{
   "total_results": 1,
   "total_pages": 1,
   "prev_url": null,
   "next_url": null,
   "resources": [
      {
         "metadata": {
            "guid": "4215794a-eeef-4de2-9a80-c73b5d1a02be",
            "url": "/v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be",
            "created_at": "2017-11-23T16:10:31Z",
            "updated_at": "2017-11-24T13:14:07Z"
         },
         "entity": {
            "name": "stubrunner",
            "production": false,
            "space_guid": "4165b38e-1bfb-4ce2-980e-d3a7eef203cf",
            "stack_guid": "86205f38-84fc-4bc2-b2b8-af7f55669f04",
            "buildpack": null,
            "detected_buildpack": "client-certificate-mapper=1.2.0_RELEASE container-security-provider=1.8.0_RELEASE java-buildpack=\u001B[34mv4.5\u001B[0m-offline-https://github.com/cloudfoundry/java-buildpack.git#ffeefb9 java-main java-opts jvmkill-agent=1.10.0_RELEASE open-jdk-like-jre=1.8.0_1...",
            "detected_buildpack_guid": "e000b78c-c898-419e-843c-2fd64175527e",
            "environment_json": {
               "JAVA_OPTS": "-Djava.security.egd=file:///dev/urandom",
               "REPO_WITH_BINARIES": "https://ciberkleid:ae71988f8b4ebe8bb4aa9cfe97a08c0d1bc6612d@dl.bintray.com/ciberkleid/maven-repo",
               "TRUST_CERTS": "api.run.pivotal.io",
               "stubrunner.ids": "io.pivotal:fortune-service:1.0.0.M1-20171106_012934-VERSION:stubs:13125",
               "eureka.client.serviceUrl.defaultZone": "${vcap.services.service-registry.credentials.uri}/eureka/"
            },
            "memory": 1024,
            "instances": 1,
            "disk_quota": 1024,
            "state": "STOPPED",
            "version": "8463fe79-e8ed-4467-a91b-2286acd09a0a",
            "command": null,
            "console": false,
            "debug": null,
            "staging_task_id": "29c9901b-69aa-4b13-b2a7-0c3272e3541a",
            "package_state": "STAGED",
            "health_check_type": "port",
            "health_check_timeout": 120,
            "health_check_http_endpoint": null,
            "staging_failed_reason": null,
            "staging_failed_description": null,
            "diego": true,
            "docker_image": null,
            "docker_credentials": {
               "username": null,
               "password": null
            },
            "package_updated_at": "2017-11-23T16:10:38Z",
            "detected_start_command": "JAVA_OPTS=\"-agentpath:$PWD/.java-buildpack/open_jdk_jre/bin/jvmkill-1.10.0_RELEASE=printHeapHistogram=1 -Djava.io.tmpdir=$TMPDIR -Djava.ext.dirs=$PWD/.java-buildpack/container_security_provider:$PWD/.java-buildpack/open_jdk_jre/lib/ext -Djava.security.properties=$PWD/.java-buildpack/security_providers/java.security $JAVA_OPTS\" && CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_jre/bin/java-buildpack-memory-calculator-3.9.0_RELEASE -totMemory=$MEMORY_LIMIT -stackThreads=300 -loadedClasses=24245 -poolType=metaspace -vmOptions=\"$JAVA_OPTS\") && echo JVM Memory Configuration: $CALCULATED_MEMORY && JAVA_OPTS=\"$JAVA_OPTS $CALCULATED_MEMORY\" && SERVER_PORT=$PORT eval exec $PWD/.java-buildpack/open_jdk_jre/bin/java $JAVA_OPTS -cp $PWD/. org.springframework.boot.loader.JarLauncher",
            "enable_ssh": true,
            "ports": [
               8080,
               10000,
               10001,
               10002
            ],
            "space_url": "/v2/spaces/4165b38e-1bfb-4ce2-980e-d3a7eef203cf",
            "stack_url": "/v2/stacks/86205f38-84fc-4bc2-b2b8-af7f55669f04",
            "routes_url": "/v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be/routes",
            "events_url": "/v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be/events",
            "service_bindings_url": "/v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be/service_bindings",
            "route_mappings_url": "/v2/apps/4215794a-eeef-4de2-9a80-c73b5d1a02be/route_mappings"
         }
      }
   ]
}
EOF
return
	else
		echo "cf $*"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	assert_output --partial "cf install-plugin do-all -r CF-Community -f"
	assert_output --partial "cf do-all delete {} -r -f"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "cf push my-project"
	refute_output --partial "cf bind-service my-project rabbitmq-my-project"
	refute_output --partial "cf bind-service my-project eureka-my-project"
	refute_output --partial "cf bind-service my-project mysql-my-project"
	assert_output --partial "cf restart my-project"
	assert_output --partial "APPLICATION_URL=my-project-sc-pipelines.demo.io"
	assert_output --partial "STUBRUNNER_URL=stubrunner-my-project-sc-pipelines.demo.io"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	assert_output --partial "cf create-service foo bar mysql-github-webhook"
	assert_output --partial "cf push eureka-github-webhook -f manifest.yml -p target/github-eureka-0.0.1.M1.jar -n eureka-github-webhook-${env} -i 1 --no-start"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial "cf cups eureka-github-webhook -p"
	# Stub Runner
	assert_output --partial "curl -u foo:bar http://foo/com/example/github/github-analytics-stub-runner-boot-classpath-stubs/0.0.1.M1/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -o"
	assert_output --partial "cf push stubrunner-github-webhook -f manifest.yml -p target/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -n stubrunner-github-webhook-${env} -i 1 --no-start"
	assert_output --partial "cf set-env stubrunner-github-webhook stubrunner.ids"
	assert_output --partial "cf restart stubrunner-github-webhook"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
	refute_output --partial "No pipeline descriptor found - will not deploy any services"
	# Creation of services
	assert_output --partial "cf create-service foo bar rabbitmq-github-webhook"
	assert_output --partial "cf create-service foo bar mysql-github-webhook"
	assert_output --partial "cf push eureka-github-webhook -f manifest.yml -p build/libs/github-eureka-0.0.1.M1.jar -n eureka-github-webhook-${env} -i 1 --no-start"
	assert_output --partial "cf restart eureka-github-webhook"
	assert_output --partial "cf cups eureka-github-webhook -p"
	# Stub Runner
	assert_output --partial "curl -u foo:bar http://foo/com/example/github/github-analytics-stub-runner-boot-classpath-stubs/0.0.1.M1/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -o"
	assert_output --partial "cf push stubrunner-github-webhook -f manifest.yml -p build/libs/github-analytics-stub-runner-boot-classpath-stubs-0.0.1.M1.jar -n stubrunner-github-webhook-${env} -i 1 --no-start"
	assert_output --partial "cf set-env stubrunner-github-webhook stubrunner.ids gradlew stubIds -q"
	assert_output --partial "cf restart stubrunner-github-webhook"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
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
	assert_output --partial "cf login -u ${env}-username -p ${env}-password -o ${env}-org -s ${env}-space"
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
	assert_output --partial "git checkout prod/1.0.0.FOO"
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

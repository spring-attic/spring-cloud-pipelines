#!/usr/bin/env bats

load 'test_helper'
load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	export TEMP_DIR="$( mktemp -d )"
	
	export MAVENW_BIN="mockMvnw"
	export GRADLEW_BIN="mockGradlew"

	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"
	export KUBE_CONFIG_PATH="${TEMP_DIR}/.kube/config"

	export DOCKER_REGISTRY_ORGANIZATION=DOCKER_REGISTRY_ORGANIZATION
	export DOCKER_REGISTRY_URL=DOCKER_REGISTRY_URL
	export DOCKER_SERVER_ID=DOCKER_SERVER_ID
	export DOCKER_USERNAME=DOCKER_USERNAME
	export DOCKER_PASSWORD=DOCKER_PASSWORD
	export DOCKER_EMAIL=DOCKER_EMAIL

	export PAAS_TEST_CA="${TEMP_DIR}/ca"
	export PAAS_TEST_CLIENT_CERT="${TEMP_DIR}/client_cert"
	export PAAS_TEST_CLIENT_KEY="${TEMP_DIR}/client_key"
	export PAAS_TEST_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_TEST_CLUSTER_USERNAME="cluster_username"
	export PAAS_TEST_CLUSTER_NAME="cluster_name"
	export PAAS_TEST_SYSTEM_NAME="cluster_name"
	export PAAS_TEST_API_URL="1.2.3.4:8765"

	export PAAS_STAGE_CA="${TEMP_DIR}/ca"
	export PAAS_STAGE_CLIENT_CERT="${TEMP_DIR}/client_cert"
	export PAAS_STAGE_CLIENT_KEY="${TEMP_DIR}/client_key"
	export PAAS_STAGE_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_STAGE_CLUSTER_USERNAME="cluster_username"
	export PAAS_STAGE_CLUSTER_NAME="cluster_name"
	export PAAS_STAGE_SYSTEM_NAME="cluster_name"
	export PAAS_STAGE_API_URL="1.2.3.4:8765"

	export PAAS_PROD_CA="${TEMP_DIR}/ca"
	export PAAS_PROD_CLIENT_CERT="${TEMP_DIR}/client_cert"
	export PAAS_PROD_CLIENT_KEY="${TEMP_DIR}/client_key"
	export PAAS_PROD_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_PROD_CLUSTER_USERNAME="cluster_username"
	export PAAS_PROD_CLUSTER_NAME="cluster_name"
	export PAAS_PROD_SYSTEM_NAME="cluster_name"
	export PAAS_PROD_API_URL="1.2.3.4:8765"

	mkdir -p "${KUBE_CONFIG_PATH}"
	cp -a "${FIXTURES_DIR}/gradle" "${FIXTURES_DIR}/maven" "${TEMP_DIR}"
}

teardown() {
	rm -rf -- "${TEMP_DIR}"
}

function curl {
	echo "curl $*"
}

function kubectl {
	echo "kubectl $*"
}

count=1
function kubectl_that_fails_first_time {
	if [[ "${1}" == "version" && "${count}" == 1 ]]; then
		return 1
	else
		count=count+1
	fi
	echo "kubectl $*"
}

function kubectl_that_returns_empty_string {
	echo ""
}

function kubectl_that_returns_empty_string_and_returns_1 {
	echo ""
	return 1
}

function kubectl_that_returns_too_many_deployments {
	echo "github-webhook-1-0-0-m1-170925-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170924-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170923-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170924-152938-version   1         1         1         1         14h"
}

function kubectl_that_returns_deployments {
	echo "github-webhook-1-0-0-m1-170925-142938-version   1         1         1         1         14h"
}

function kubectl_that_returns_parsed_too_many_deployments {
	echo "github-webhook-1-0-0-m1-170925-142938-version"
	echo "github-webhook-1-0-0-m1-170924-142938-version"
	echo "github-webhook-1-0-0-m1-170923-142938-version"
	echo "github-webhook-1-0-0-m1-170924-152938-version"
}

function mockMvnw {
	echo "mvnw $*"
}

function mockGradlew {
	echo "gradlew $*"
}

export -f curl
export -f kubectl
export -f kubectl_that_fails_first_time
export -f kubectl_that_returns_empty_string
export -f kubectl_that_returns_too_many_deployments
export -f kubectl_that_returns_deployments
export -f kubectl_that_returns_parsed_too_many_deployments
export -f kubectl_that_returns_empty_string_and_returns_1
export -f mockMvnw
export -f mockGradlew

@test "should pass docker related properties to the build [K8S][Maven]" {
	export ENVIRONMENT=BUILD
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run build

	assert_output --partial "mvnw clean verify deploy -Ddistribution.management.release.id="
	assert_output --partial "distribution.management.release.url"
	assert_output --partial "repo.with.binaries"
	assert_output --partial "DOCKER_REGISTRY_ORGANIZATION=DOCKER_REGISTRY_ORGANIZATION"
	assert_output --partial "DOCKER_REGISTRY_URL=DOCKER_REGISTRY_URL"
	assert_output --partial "DOCKER_SERVER_ID=DOCKER_SERVER_ID"
	assert_output --partial "DOCKER_USERNAME=DOCKER_USERNAME"
	assert_output --partial "DOCKER_PASSWORD=DOCKER_PASSWORD"
	assert_output --partial "DOCKER_EMAIL=DOCKER_EMAIL"
	assert_success
}

@test "should download kubectl if it's missing and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${TEMP_DIR}/maven/empty_project"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [false]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
	assert_success
}

@test "should redownload kubectl if redownload infra flag is set and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="true"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [true]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
	assert_success
}

@test "should not redownload kubectl if redownload infra flag is not set and kubectl was downloaded and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
	assert_success
}

@test "should use token from env var to connect to the cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export TOKEN="FOO"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --token=FOO"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
	assert_success
}

@test "should use token from a file to connect to the cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export PAAS_TEST_CLIENT_TOKEN_PATH="${TEMP_DIR}/maven/empty_project/token"
	cd "${TEMP_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	echo "FOO" > token
	source "${SOURCE_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --token=FOO"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
	assert_success
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment with additional services for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment with additional services for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment with additional services for non-minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to test environment with additional services for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f ${OUTPUT_DIR}/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should prepare and execute smoke tests for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
	assert_success
}

@test "should prepare and execute smoke tests for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
	assert_success
}

@test "should prepare and execute smoke tests for non minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
	assert_success
}

@test "should prepare and execute smoke tests for non minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
	assert_success
}

@test "should deploy app for rollback tests without additional services if pipeline descriptor is missing for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to rollback test environment with additional services for non-minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to rollback test environment with additional services for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should skip the rollback step if no prod deployment took place [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No prod release took place - skipping this step"
	refute_output --partial "-Psmoke"
	assert_success
}

@test "should prepare and execute rollback tests for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
	assert_success
}

@test "should prepare and execute rollback tests for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
	assert_success
}

@test "should prepare and execute rollback tests for non minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
	assert_success
}

@test "should prepare and execute rollback tests for non minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/test_rollback_smoke.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
	assert_success
}

@test "should deploy app for e2e tests without additional services if pipeline descriptor is missing for minikube [K8S][Gradle]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-stage"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to stage environment with additional services for non-minikube [K8S][Gradle]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-stage"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should deploy app to stage environment with additional services for minikube [K8S][Gradle]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-stage"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	export LATEST_PROD_TAG="prod/1.0.0.FOO"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
	assert_success
}

@test "should prepare and execute e2e tests for minikube [K8S][Maven]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-stage"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Pe2e"
	assert_success
}

@test "should prepare and execute e2e tests for minikube [K8S][Gradle]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew e2e"
	assert_success
}

@test "should prepare and execute e2e tests for non minikube [K8S][Maven]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-stage"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Pe2e"
	assert_success
}

@test "should prepare and execute e2e tests for non minikube [K8S][Gradle]" {
	export ENVIRONMENT="STAGE"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/stage_e2e.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew e2e"
	assert_success
}

@test "should escape non DNS valid name [K8S]" {
	source "${SOURCE_DIR}/pipeline-k8s.sh"

	run escapeValueForDns "a_b_1.2.3"

	assert_output "a-b-1-2-3"
	assert_success
}

@test "should not escape a valid DNS name [K8S]" {
	source "${SOURCE_DIR}/pipeline-k8s.sh"

	run escapeValueForDns "a-b-1-2-3"

	assert_output "a-b-1-2-3"
	assert_success
}

@test "should return false if object hasn't been deployed [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_empty_string"
	source "${SOURCE_DIR}/pipeline-k8s.sh"

	result="$( objectDeployed "service" "bar" )"

	assert_equal "${result}" "false"
	assert_success
}

@test "should return true if object has been deployed [K8S]" {
	export KUBECTL_BIN="kubectl"
	source "${SOURCE_DIR}/pipeline-k8s.sh"

	result="$( objectDeployed "service" "bar" )"

	assert_equal "${result}" "true"
	assert_success
}

@test "should deploy blue instance for non minikube [K8S][Maven]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}"/prod_deploy.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_success
}

@test "should deploy blue instance for non minikube [K8S][Gradle]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}"/prod_deploy.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_success
}

@test "should fail to deploy blue instance for non minikube when green is already deployed [K8S][Maven]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl_that_returns_parsed_too_many_deployments"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}"/prod_deploy.sh

	# logged in
	refute_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "Green already deployed. Please complete switch over first"
	assert_failure
}

@test "should fail to deploy blue instance for non minikube when green is already deployed [K8S][Gradle]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl_that_returns_parsed_too_many_deployments"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}"/prod_deploy.sh

	# logged in
	refute_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "Green already deployed. Please complete switch over first"
	assert_failure
}

@test "should return the dns escaped app name [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_too_many_deployments"
	export PIPELINE_VERSION="1.0.0.M1-170925_142938-VERSION"
	source "${SOURCE_DIR}/pipeline-k8s.sh"

	result="$( dnsEscapedAppNameWithVersionSuffix "github-webhook-${PIPELINE_VERSION}" )"

	assert_equal "${result}" "github-webhook-1-0-0-m1-170925-142938-version"
}

@test "should return list of deployed apps [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_too_many_deployments"
	source "${SOURCE_DIR}/pipeline-k8s.sh"
	deployments="$( kubectl_that_returns_too_many_deployments )"
	expected="$( echo -e "github-webhook-1-0-0-m1-170925-142938-version\ngithub-webhook-1-0-0-m1-170924-142938-version\ngithub-webhook-1-0-0-m1-170924-152938-version" )"
	result="$( otherDeployedInstances "github-webhook" "github-webhook-1-0-0-m1-170923-142938-version" )"

	assert_equal "${result}" "${expected}"
	assert_success
}

@test "should not return invalid code when empty list of deployed apps is returned [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_empty_string_and_returns_1"
	source "${SOURCE_DIR}/pipeline-k8s.sh"
	deployments="$( kubectl_that_returns_too_many_deployments )"
	result="$( otherDeployedInstances "github-webhook" "github-webhook-1-0-0-m1-170923-142938-version" )"

	assert_equal "${result}" ""
	assert_success
}

@test "should return an empty string when no deployments are matched [K8S]" {
	export PIPELINE_VERSION="1.0.0.M1-170925_142938-VERSION"
	source "${SOURCE_DIR}/pipeline-k8s.sh"
	deployments="$( kubectl_that_returns_empty_string )"

	result="$( oldestDeployment "${deployments}" )"

	assert_equal "${result}" ""
	assert_success
}

@test "should return the oldest deployment by sorting the deployment names [K8S]" {
	export PIPELINE_VERSION="1.0.0.M1-170925_142938-VERSION"
	source "${SOURCE_DIR}/pipeline-k8s.sh"
	deployments="$( kubectl_that_returns_parsed_too_many_deployments )"

	result="$( oldestDeployment "${deployments}" )"

	assert_equal "${result}" "github-webhook-1-0-0-m1-170923-142938-version"
	assert_success
}

@test "should delete green instance for non minikube [K8S][Maven]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
	assert_success
}

@test "should delete green instance for non minikube [K8S][Gradle]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
	assert_success
}

@test "should delete green instance for non minikube [K8S][Maven]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
	assert_success
}

@test "should delete green instance for non minikube [K8S][Gradle]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_complete.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
	assert_success
}

@test "should rollback to blue [K8S][Maven]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "scale deployment"
	assert_success
}

@test "should rollback to blue [K8S][Gradle]" {
	export ENVIRONMENT="PROD"
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-prod"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${FIXTURES_DIR}/sc-pipelines.yml" "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${TEMP_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${SOURCE_DIR}/prod_rollback.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "scale deployment"
	assert_success
}

#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"

	export MAVENW_BIN="mockMvnw"
	export GRADLEW_BIN="mockGradlew"

	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"
	export KUBE_CONFIG_PATH="${PIPELINES_TEST_DIR}/.kube/config"
	mkdir -p "${KUBE_CONFIG_PATH}"

	export PAAS_TEST_CA_PATH="${PIPELINES_TEST_DIR}/ca"
	export PAAS_TEST_CLIENT_CERT_PATH="${PIPELINES_TEST_DIR}/client_cert"
	export PAAS_TEST_CLIENT_KEY_PATH="${PIPELINES_TEST_DIR}/client_key"
	export PAAS_TEST_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_TEST_CLUSTER_USERNAME="cluster_username"
	export PAAS_TEST_CLUSTER_NAME="cluster_name"
	export PAAS_TEST_SYSTEM_NAME="cluster_name"
	export PAAS_TEST_API_URL="1.2.3.4:8765"

	export PAAS_STAGE_CA_PATH="${PIPELINES_TEST_DIR}/ca"
	export PAAS_STAGE_CLIENT_CERT_PATH="${PIPELINES_TEST_DIR}/client_cert"
	export PAAS_STAGE_CLIENT_KEY_PATH="${PIPELINES_TEST_DIR}/client_key"
	export PAAS_STAGE_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_STAGE_CLUSTER_USERNAME="cluster_username"
	export PAAS_STAGE_CLUSTER_NAME="cluster_name"
	export PAAS_STAGE_SYSTEM_NAME="cluster_name"
	export PAAS_STAGE_API_URL="1.2.3.4:8765"

	export PAAS_PROD_CA_PATH="${PIPELINES_TEST_DIR}/ca"
	export PAAS_PROD_CLIENT_CERT_PATH="${PIPELINES_TEST_DIR}/client_cert"
	export PAAS_PROD_CLIENT_KEY_PATH="${PIPELINES_TEST_DIR}/client_key"
	export PAAS_PROD_CLIENT_TOKEN_PATH=""
	export TOKEN=""
	export PAAS_PROD_CLUSTER_USERNAME="cluster_username"
	export PAAS_PROD_CLUSTER_NAME="cluster_name"
	export PAAS_PROD_SYSTEM_NAME="cluster_name"
	export PAAS_PROD_API_URL="1.2.3.4:8765"
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

function kubectl_that_returns_deployments {
	echo "github-webhook-1-0-0-m1-170925-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170924-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170923-142938-version   1         1         1         1         14h"
	echo "github-webhook-1-0-0-m1-170924-152938-version   1         1         1         1         14h"
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
export -f kubectl_that_returns_deployments
export -f mockMvnw
export -f mockGradlew

@test "should download kubectl if it's missing and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${PIPELINES_TEST_DIR}/maven/empty_project"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [false]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA_PATH} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA_PATH} --client-key=${PAAS_TEST_CLIENT_KEY_PATH} --client-certificate=${PAAS_TEST_CLIENT_CERT_PATH}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should redownload kubectl if redownload infra flag is set and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="true"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${PIPELINES_TEST_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [true]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA_PATH} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA_PATH} --client-key=${PAAS_TEST_CLIENT_KEY_PATH} --client-certificate=${PAAS_TEST_CLIENT_CERT_PATH}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should not redownload kubectl if redownload infra flag is not set and kubectl was downloaded and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	cd "${PIPELINES_TEST_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA_PATH} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA_PATH} --client-key=${PAAS_TEST_CLIENT_KEY_PATH} --client-certificate=${PAAS_TEST_CLIENT_CERT_PATH}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should use token from env var to connect to the cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export TOKEN="FOO"
	cd "${PIPELINES_TEST_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA_PATH} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --token=FOO"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should use token from a file to connect to the cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export PAAS_TEST_CLIENT_TOKEN_PATH="${PIPELINES_TEST_DIR}/maven/empty_project/token"
	cd "${PIPELINES_TEST_DIR}/maven/empty_project"
	touch "${KUBECTL_BIN}"
	echo "FOO" > token
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA_PATH} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --token=FOO"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

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
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

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
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for non-minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

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
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_deploy.sh"

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
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should prepare and execute smoke tests for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
}

@test "should prepare and execute smoke tests for minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
}

@test "should prepare and execute smoke tests for non minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
}

@test "should prepare and execute smoke tests for non minikube [K8S][Gradle]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	export BUILD_PROJECT_TYPE="gradle"
	export OUTPUT_DIR="build/libs"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
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
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/test_rollback_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "Last prod version equals 1.0.0.FOO"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should skip the rollback step if no prod deployment took place [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	export BUILD_PROJECT_TYPE="maven"
	export OUTPUT_DIR="target"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_rollback_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No prod release took place - skipping this step"
	refute_output --partial "-Psmoke"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_rollback_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_rollback_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_rollback_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Psmoke"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/test_rollback_smoke.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew smoke"
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
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}/stage_deploy.sh"

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage delete -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-stage create -f ${OUTPUT_DIR}/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/stage_e2e.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Pe2e"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/stage_e2e.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew e2e"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/stage_e2e.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "-Pe2e"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/stage_e2e.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "gradlew e2e"
}

@test "should escape non DNS valid name [K8S]" {
	source "${PIPELINES_TEST_DIR}"/pipeline-k8s.sh

	run escapeValueForDns "a_b_1.2.3"

	assert_output "a-b-1-2-3"
}

@test "should not escape a valid DNS name [K8S]" {
	source "${PIPELINES_TEST_DIR}"/pipeline-k8s.sh

	run escapeValueForDns "a-b-1-2-3"

	assert_output "a-b-1-2-3"
}

@test "should return false if object hasn't been deployed [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_empty_string"
	source "${PIPELINES_TEST_DIR}"/pipeline-k8s.sh

	result="$( objectDeployed "service" "bar" )"

	assert_equal "${result}" "false"
}

@test "should return true if object has been deployed [K8S]" {
	export KUBECTL_BIN="kubectl"
	source "${PIPELINES_TEST_DIR}"/pipeline-k8s.sh

	result="$( objectDeployed "service" "bar" )"

	assert_equal "${result}" "true"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/prod_deploy.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/prod_deploy.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	refute_output --partial "kubectl --context=context --namespace=sc-pipelines-prod create -f ${OUTPUT_DIR}/k8s/service.yml"
}

@test "should return the oldest deployment by sorting the deployment names [K8S]" {
	export KUBECTL_BIN="kubectl_that_returns_deployments"
	export PIPELINE_VERSION="1.0.0.M1-170925_142938-VERSION"
	source "${PIPELINES_TEST_DIR}"/pipeline-k8s.sh

	result="$( oldestDeployment "github-webhook" )"

	assert_equal "${result}" "github-webhook-1-0-0-m1-170923-142938-version"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/prod_complete.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
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
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	cd "${PIPELINES_TEST_DIR}/${BUILD_PROJECT_TYPE}/empty_project"
	touch "${KUBECTL_BIN}"

	run "${PIPELINES_TEST_DIR}"/prod_complete.sh

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "delete deployment"
}

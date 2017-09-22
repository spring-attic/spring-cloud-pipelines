#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
	source "${BATS_TEST_DIRNAME}/test_helper/setup.bash"

	export ENVIRONMENT="TEST"
	export PAAS_TYPE="k8s"
	export KUBE_CONFIG_PATH="${PIPELINES_TEST_DIR}/.kube/config"
	mkdir -p "${KUBE_CONFIG_PATH}"
	export PAAS_TEST_CA="${PIPELINES_TEST_DIR}/ca"
	export PAAS_TEST_CLIENT_CERT="${PIPELINES_TEST_DIR}/client_cert"
	export PAAS_TEST_CLIENT_KEY="${PIPELINES_TEST_DIR}/client_key"
	export PAAS_TEST_CLUSTER_USERNAME="cluster_username"
	export PAAS_TEST_CLUSTER_NAME="cluster_name"
	export PAAS_TEST_SYSTEM_NAME="cluster_name"
	export PAAS_TEST_API_URL="1.2.3.4:8765"
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

export -f curl
export -f kubectl
export -f kubectl_that_fails_first_time

@test "should download kubectl if it's missing and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [false]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should redownload kubectl if redownload infra flag is set and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="true"
	export KUBECTL_BIN="kubectl_that_fails_first_time"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	assert_output --partial "CLI Installed? [false], CLI Downloaded? [true]"
	assert_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should not redownload kubectl if redownload infra flag is not set and kubectl was downloaded and connect to cluster [K8S]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert [ ! -f "${KUBE_CONFIG_PATH}" ]
	refute_output --partial "curl -LO https://storage.googleapis.com"
	assert_output --partial "Adding CLI to PATH"
	assert_output --partial "kubectl config set-cluster cluster_name --server=https://1.2.3.4:8765 --certificate-authority=${PAAS_TEST_CA} --embed-certs=true"
	assert_output --partial "kubectl config set-credentials cluster_username --certificate-authority=${PAAS_TEST_CA} --client-key=${PAAS_TEST_CLIENT_KEY} --client-certificate=${PAAS_TEST_CLIENT_CERT}"
	assert_output --partial "kubectl config set-context cluster_name --cluster=cluster_name --user=cluster_username"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run testDeploy

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment without additional services if pipeline descriptor is missing for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export KUBERNETES_MINIKUBE="true"
	export PAAS_NAMESPACE="sc-pipelines-test"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run testDeploy

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "No pipeline descriptor found - will not deploy any services"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "-o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for non-minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="false"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/maven/build_project"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run testDeploy

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-my-project --from-literal=username= --from-literal=password= --from-literal=rootpassword="
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "my-project -o jsonpath={.spec.ports[0].port}/health"
	assert_output --partial "App started successfully!"
}

@test "should deploy app to test environment with additional services for minikube [K8S][Maven]" {
	export REDOWNLOAD_INFRA="false"
	export KUBECTL_BIN="kubectl"
	export K8S_CONTEXT="context"
	export PAAS_NAMESPACE="sc-pipelines-test"
	export KUBERNETES_MINIKUBE="true"
	cp "${BATS_TEST_DIRNAME}/fixtures/sc-pipelines.yml" "${PIPELINES_TEST_DIR}/maven/build_project"
	cd "${PIPELINES_TEST_DIR}/maven/build_project"
	touch "${KUBECTL_BIN}"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run testDeploy

	# logged in
	assert_output --partial "kubectl config use-context cluster_name"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret rabbitmq-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/rabbitmq-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret mysql-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create secret generic mysql-my-project --from-literal=username= --from-literal=password= --from-literal=rootpassword="
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/mysql-service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret eureka-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/eureka-service.yml"
	assert_output --partial "eureka-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete secret stubrunner-github-webhook"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test replace --force -f target/k8s/stubrunner-service.yml"
	assert_output --partial "stubrunner-github-webhook -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test delete -f target/k8s/service.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/deployment.yml"
	assert_output --partial "kubectl --context=context --namespace=sc-pipelines-test create -f target/k8s/service.yml"
	assert_output --partial "my-project -o jsonpath={.spec.ports[0].nodePort}/health"
	assert_output --partial "App started successfully!"
}

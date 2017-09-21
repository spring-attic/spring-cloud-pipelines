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
	export PAAS_TEST_CLUSTER_NAME="cluster_name"
	export PAAS_TEST_SYSTEM_NAME="cluster_name"
	export PAAS_TEST_API_URL="http://1.2.3.4:8765"
}

function curl {
    echo "curl"
}

function kubectl {
    echo "kubectl"
}

export -f curl
export -f kubectl

@test "should download kubectl if it's missing" {
	skip
	export REDOWNLOAD_INFRA="false"
	source "${PIPELINES_TEST_DIR}/pipeline.sh"

	run logInToPaas

	assert_output "foo"
}

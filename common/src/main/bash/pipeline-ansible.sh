#!/bin/bash

set -e

__ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_INVENTORY_DIR="${ANSIBLE_INVENTORY_DIR:-ansible-inventory}"
ANSIBLE_PLAYBOOKS_DIR="${ANSIBLE_PLAYBOOKS_DIR:-${__ROOT}/ansible}"
ANSIBLE_CUSTOM_PLAYBOOKS_DIR="${ANSIBLE_CUSTOM_PLAYBOOKS_DIR:-${__ROOT}/ansible/custom}"
PIPELINE_DESCRIPTOR="$( pwd )/${PIPELINE_DESCRIPTOR}"
ENVIRONMENT="${ENVIRONMENT:?}"

function __ansible_inventory() {
	local environment

	environment="$( toLowerCase "${ENVIRONMENT}" )"
	if [[ ! -f "${ANSIBLE_INVENTORY_DIR}/${environment}" ]]; then
		echo "Could not find inventory!"
		exit 1
	fi
	ansible-inventory -i "${ANSIBLE_INVENTORY_DIR}/${environment}" "$@"
}

function __ansible_playbook() {
	local playbook_name="$1"
	local environment
	local playbook_path
	shift
	environment="$( toLowerCase "${ENVIRONMENT}" )"
	if [[ ! -f "${ANSIBLE_INVENTORY_DIR}/${environment}" ]]; then
		echo "Could not find inventory!"
		exit 1
	fi
	playbook_path="${ANSIBLE_PLAYBOOKS_DIR}/${playbook_name}"
	if [[ -f "${ANSIBLE_CUSTOM_PLAYBOOKS_DIR}/${playbook_name}" ]]; then
		echo "Found custom playbook [${playbook_name}]"
		playbook_path="${ANSIBLE_CUSTOM_PLAYBOOKS_DIR}/${playbook_name}"
	fi
	echo "Executing playbook [${playbook_path}]"
	ANSIBLE_HOST_KEY_CHECKING="False" \
	ANSIBLE_STDOUT_CALLBACK="debug" \
	ansible-playbook -D -i "${ANSIBLE_INVENTORY_DIR}/${environment}" \
		"${playbook_path}" "$@"
}

function logInToPaas() {
	:
}

function testDeploy() {
	local appName

	appName="$( retrieveAppName )"

	__ansible_playbook bootstrap-environment.yml \
		-e "force_clean=true"

	__ansible_playbook deploy-stubrunner.yml \
		-e "app_name=${appName}" \
		-e "stubrunner_ids=$( retrieveStubRunnerIds )"

	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=${appName}" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${PIPELINE_VERSION}"
}

function testRollbackDeploy() {
	local latestProdTag="${1}"
	local latestProdVersion

	latestProdVersion="${latestProdTag#prod/}"

	rm -rf -- "${OUTPUT_FOLDER}/test.properties"
	mkdir -p "${OUTPUT_FOLDER}"

	echo "Last prod version equals ${latestProdVersion}"

	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=$( retrieveAppName )" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${latestProdVersion}"

	# get the application and stubrunner URLs
	prepareForSmokeTests

	cat <<-EOF > "${OUTPUT_FOLDER}/test.properties"
	APPLICATION_URL=${APPLICATION_URL}
	STUBRUNNER_URL=${STUBRUNNER_URL}
	LATEST_PROD_TAG=${latestProdTag}
	EOF
}

function prepareForSmokeTests() {
	local applicationHost
	local applicationPort
	local stubrunnerHost
	local stubrunnerPort
	local appName

	appName="$( retrieveAppName )"

	# we assume that we have only one test instance
	applicationHost="$( __ansible_inventory --list | jq -r '.app_server.hosts[0]' )"
	applicationPort="$( __ansible_inventory --host "${applicationHost}" | jq -r ".\"${appName}_port\"" )"

	# and we assume that stubrunner should run on the same host
	stubrunnerHost="${applicationHost}"
	stubrunnerPort="$( __ansible_inventory --host "${stubrunnerHost}" | jq -r ".\"${appName}_stubrunner_port\"" )"

	export APPLICATION_URL="${applicationHost}:${applicationPort}"
	export STUBRUNNER_URL="${stubrunnerHost}:${stubrunnerPort}"
}

function stageDeploy() {
	__ansible_playbook bootstrap-environment.yml

	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=$( retrieveAppName )" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${PIPELINE_VERSION}"
}

function prepareForE2eTests() {
	local applicationHost
	local applicationPort
	local appName

	appName="$( retrieveAppName )"

	# we assume that we have only one test instance
	applicationHost="$( __ansible_inventory --list | jq -r '.app_server.hosts[0]' )"
	applicationPort="$( __ansible_inventory --host "${applicationHost}" | jq -r ".\"${appName}_port\"" )"

	export APPLICATION_URL="${applicationHost}:${applicationPort}"
}

function prodDeploy() {
	__ansible_playbook bootstrap-environment.yml

	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=$( retrieveAppName )" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${PIPELINE_VERSION}" \
		-e "target=blue"
}

function completeSwitchOver() {
	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=$( retrieveAppName )" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${PIPELINE_VERSION}" \
		-e "target=green"
}

function rollbackToPreviousVersion() {
	__ansible_playbook "deploy-${LANGUAGE_TYPE}-service.yml" \
		-e "app_name=$( retrieveAppName )" \
		-e "app_group_id=$( retrieveGroupId )" \
		-e "app_version=${PIPELINE_VERSION}"
}

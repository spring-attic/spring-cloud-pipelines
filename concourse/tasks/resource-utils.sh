#!/bin/bash
# shellcheck disable=SC2086,SC1007,SC2163,SC2046,SC2153

set -o errexit
set -o errtrace
set -o pipefail

export TMPDIR=${TMPDIR:-/tmp}
[[ -z "${SSH_HOME}" ]] && SSH_HOME="${HOME}/.ssh"
export SSH_AGENT_BIN="${SSH_AGENT_BIN:-ssh-agent}"
export TEST_MODE="${TEST_MODE:-false}"

# Reads all key-value pairs in keyval.properties input file and exports them as env vars
function exportKeyValProperties() {
	props="${ROOT_FOLDER}/${KEYVAL_RESOURCE}/keyval.properties"
	echo "Props are in [${props}]"
	if [ -f "${props}" ]
	then
	  echo "Reading passed key values"
	  while IFS= read -r var
	  do
		if [ ! -z "${var}" ]
		then
			echo "Adding: ${var}"
			export "$var"
		fi
	  done < "${props}"
	fi
}

# Writes all env vars that begin with PASSED_ to the keyval.properties output file
function passKeyValProperties() {
	propsDir="${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
	propsFile="${propsDir}/keyval.properties"
	if [ -d "${propsDir}" ]
	then
	  touch "${propsFile}"
	  echo "Setting key values for next job in ${propsFile}"
	  while IFS='=' read -r name value ; do
		if [[ "${name}" == 'PASSED_'* ]]; then
			echo "Adding: ${name}=${value}"
			echo "${name}=${value}" >> "${propsFile}"
		fi
		done < <(env)
	fi
}

# Loads git key - needed for prod-rollback to delete prod tag after rollback
function load_pubkey() {

  local private_key_path="${TMPDIR}"/git-resource-private-key

  if [ -s ${private_key_path} ]; then
	echo "Git private key exists"
	chmod 0600 ${private_key_path}
	echo "Chmodded the private key"
	eval $("${SSH_AGENT_BIN}") >/dev/null 2>&1
	echo "Evaled ssh agent"
	if [[ "${TEST_MODE}" != "true" ]]; then
		# shellcheck disable=SC2046
		trap 'kill $SSH_AGENT_PID' 0
		SSH_ASKPASS=$(dirname $0)/askpass.sh DISPLAY= ssh-add $private_key_path >/dev/null
		echo "Asked for password"
	fi
	mkdir -p "${SSH_HOME}"
	echo "Created a folder for SSH"
	cat > "${SSH_HOME}"/config <<EOF
StrictHostKeyChecking no
LogLevel quiet
EOF
	echo "Added default configuration for SSH"
	chmod 0600 "${SSH_HOME}"/config
	echo "Chmodded the configuration"
  fi
}

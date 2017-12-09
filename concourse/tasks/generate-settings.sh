#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

M2_HOME="${HOME}/.m2"
M2_CACHE="${ROOT_FOLDER}/maven"
GRADLE_HOME="${HOME}/.gradle"
GRADLE_CACHE="${ROOT_FOLDER}/gradle"

echo "Generating symbolic links for caches"

[[ -d "${M2_CACHE}" && ! -d "${M2_HOME}" ]] && ln -s "${M2_CACHE}" "${M2_HOME}"
[[ -d "${GRADLE_CACHE}" && ! -d "${GRADLE_HOME}" ]] && ln -s "${GRADLE_CACHE}" "${GRADLE_HOME}"

echo "Writing maven settings to [${M2_HOME}/settings.xml]"

cat > "${M2_HOME}/settings.xml" <<EOF

<?xml version="1.0" encoding="UTF-8"?>
<settings>
	<servers>
		<server>
			<id>\${M2_SETTINGS_REPO_ID}</id>
			<username>\${M2_SETTINGS_REPO_USERNAME}</username>
			<password>\${M2_SETTINGS_REPO_PASSWORD}</password>
		</server>
		<server>
			<id>\${DOCKER_SERVER_ID}</id>
			<username>\${DOCKER_USERNAME}</username>
			<password>\${DOCKER_PASSWORD}</password>
			<configuration>
				<email>\${DOCKER_EMAIL}</email>
			</configuration>
		</server>
	</servers>
</settings>


EOF
echo "Settings xml written"

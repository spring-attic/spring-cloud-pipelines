#!/bin/bash

mkdir -p ${HOME}/.m2
mkdir -p ${HOME}/.gradle

ROOT_IN_M2_RESOURCE="${ROOT_FOLDER}/${M2_REPO}/root"
export M2_HOME="${ROOT_IN_M2_RESOURCE}/.m2"
export NEW_LOCAL_REPO="${M2_HOME}/repository/"

set +x
cat > ${HOME}/.m2/settings.xml <<EOF

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                          https://maven.apache.org/xsd/settings-1.0.0.xsd">
      <servers>
        <server>
          <id>${M2_SETTINGS_REPO_ID}</id>
          <username>${M2_SETTINGS_REPO_USERNAME}</username>
          <password>${M2_SETTINGS_REPO_PASSWORD}</password>
        </server>
      </servers>
</settings>

EOF
set -x

echo "Settings xml written"

export GRADLE_USER_HOME="${ROOT_IN_M2_RESOURCE}/.gradle"

echo "Writing gradle.properties to [${GRADLE_USER_HOME}/gradle.properties]"

set +x
cat > ${GRADLE_USER_HOME}/gradle.properties <<EOF

repoUsername=${M2_SETTINGS_REPO_USERNAME}
repoPassword=${M2_SETTINGS_REPO_PASSWORD}

EOF
set -x

echo "gradle.properties written"

echo "Moving [${NEW_LOCAL_REPO}] [${HOME}] folder"
mv ${NEW_LOCAL_REPO} ${HOME}/.m2/repository
mv ${M2_HOME}/wrapper ${HOME}/.m2/wrapper
set -x

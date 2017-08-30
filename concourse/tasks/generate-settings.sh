#!/bin/bash

mkdir -p ${HOME}/.m2
mkdir -p ${HOME}/.gradle

# Maven wrapper script downloads the wrapper to $MAVEN_USER_HOME/wrapper
export MAVEN_USER_HOME="${ROOT_FOLDER}/.m2"
mkdir -p ${MAVEN_USER_HOME}

export M2_HOME=${HOME}/.m2

echo "Writing maven settings to [${M2_HOME}/settings.xml]"

cat > ${M2_HOME}/settings.xml <<EOF

<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                          https://maven.apache.org/xsd/settings-1.0.0.xsd">
      <localRepository>${MAVEN_USER_HOME}/repository</localRepository>
      <servers>
        <server>
          <id>${M2_SETTINGS_REPO_ID}</id>
          <username>${M2_SETTINGS_REPO_USERNAME}</username>
          <password>${M2_SETTINGS_REPO_PASSWORD}</password>
        </server>
      </servers>
</settings>

EOF
echo "Settings xml written"

export GRADLE_USER_HOME="${ROOT_FOLDER}/.gradle"

echo "Writing gradle.properties to [${GRADLE_USER_HOME}/gradle.properties]"

cat > ${GRADLE_USER_HOME}/gradle.properties <<EOF

repoUsername=${M2_SETTINGS_REPO_USERNAME}
repoPassword=${M2_SETTINGS_REPO_PASSWORD}

EOF
echo "gradle.properties written"

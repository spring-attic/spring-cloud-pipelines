#!/bin/bash

mkdir -p ${HOME}/.m2/
mkdir -p ${HOME}/.gradle/

echo "Writing settings xml to [${HOME}/.m2/settings.xml]"

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

echo "Writing gradle.properties to [${HOME}/.gradle/gradle.properties]"

set +x
cat > ${HOME}/.gradle/gradle.properties <<EOF

repoUsername=${M2_SETTINGS_REPO_USERNAME}
repoPassword=${M2_SETTINGS_REPO_PASSWORD}

EOF
set -x

echo "gradle.properties written"

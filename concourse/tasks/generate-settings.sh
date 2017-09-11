#!/bin/bash

M2_HOME="${HOME}/.m2"
M2_CACHE="${ROOT_FOLDER}/maven"
GRADLE_HOME="${HOME}/.gradle"
GRADLE_CACHE="${ROOT_FOLDER}/gradle"

[[ -d $M2_CACHE && ! -d $M2_HOME ]] && ln -s $M2_CACHE $M2_HOME
[[ -d $GRADLE_CACHE && ! -d $GRADLE_HOME ]] && ln -s $GRADLE_CACHE $GRADLE_HOME

echo "Writing maven settings to [${M2_HOME}/settings.xml]"

cat > $M2_HOME/settings.xml <<EOF

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
echo "Settings xml written"

echo "Writing gradle.properties to [${GRADLE_HOME}/gradle.properties]"

cat > $GRADLE_HOME/gradle.properties <<EOF

repoUsername=${M2_SETTINGS_REPO_USERNAME}
repoPassword=${M2_SETTINGS_REPO_PASSWORD}

EOF
echo "gradle.properties written"

# Useful:
#   http://www.catosplace.net/blog/2015/02/11/running-jenkins-in-docker-containers/
#   https://github.com/jenkinsci/docker#preinstalling-plugins
#   https://engineering.riotgames.com/news/jenkins-docker-proxies-and-compose

FROM jenkins:2.19.1
ARG gituser=changeme
ARG gitpass=changeme

MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY seed/init.groovy /usr/share/jenkins/ref/init.groovy
COPY seed/jenkins_pipeline.groovy /usr/share/jenkins/jenkins_pipeline.groovy
COPY seed/settings.xml /usr/share/jenkins/settings.xml
COPY seed/gradle.properties /usr/share/jenkins/gradle.properties

USER root

# Generated via start.sh
# If you don't want to provide it just put empty files there
RUN printf "%s" "${gituser}" > /usr/share/jenkins/gituser
RUN printf "%s" "${gitpass}" > /usr/share/jenkins/gitpass

USER root

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false -Djava.awt.headless=true -Dhudson.model.ParametersAction.keepUndefinedParameters=true

RUN apt-get update && apt-get install -y \
  ruby \
  curl

USER jenkins

RUN install-plugins.sh ez-templates:1.2.1 mailer:1.17 analysis-core:1.79 junit:1.18 mask-passwords:2.8 ant:1.4 conditional-buildstep:1.3.5 credentials:2.1.4 ivy:1.26 pipeline-input-step:2.1 greenballs:1.15 javadoc:1.4 parameterized-trigger:2.32 token-macro:1.12.1 antisamy-markup-formatter:1.5 pipeline-stage-view:2.0 ldap:1.12 github-organization-folder:1.4 git-server:1.7 workflow-cps-global-lib:2.2 role-strategy:2.3.2 github-branch-source:1.9 cloudbees-folder:5.12 build-pipeline-plugin:1.5.4 jquery:1.11.2-0 build-timeout:1.17.1 sonar:2.4.4 subversion:2.6 discard-old-build:1.05 workflow-job:2.6 node-iterator-api:1.5 timestamper:1.8.5 structs:1.5 ws-cleanup:0.30 external-monitor-job:1.6 configurationslicing:1.45 dashboard-view:2.9.10 groovy:1.29 windows-slaves:1.2 nodejs:0.2.1 ssh-slaves:1.11 workflow-cps:2.13 workflow-aggregator:2.3 workflow-scm-step:2.2 durable-task:1.12 nested-view:1.14 msbuild:1.26 run-condition:1.0 ssh-credentials:1.12 job-dsl:1.50 thinBackup:1.7.4 workflow-api:2.2 slack:2.0.1 branch-api:1.10 handlebars:1.1.1 matrix-project:1.7.1 build-monitor-plugin:1.10+build.201608030223 build-name-setter:1.6.5 heavy-job:1.1 github-api:1.77 momentjs:1.1.1 jobConfigHistory:2.15 icon-shim:2.0.3 pipeline-rest-api:2.0 ec2:1.35 email-ext:2.47 copyartifact:1.38.1 git:2.5.3 matrix-auth:1.4 credentials-binding:1.9 bouncycastle-api:2.16.0 ansicolor:0.4.2 workflow-multibranch:2.8 git-client:1.21.0 ace-editor:1.1 extra-columns:1.17 pipeline-build-step:2.2 performance:1.14 jackson2-api:2.7.3 gradle:1.25 envinject:1.92.1 toolenv:1.1 config-file-provider:2.11 workflow-step-api:2.3 plain-credentials:1.2 pipeline-stage-step:2.2 maven-plugin:2.13 workflow-support:2.2 delivery-pipeline-plugin:0.9.12 ssh:2.4 next-build-number:1.4 script-security:1.22 rebuild:1.25 cloudfoundry:1.5 aws-credentials:1.16 aws-java-sdk:1.10.50 workflow-durable-task-step:2.4 jenkins-multijob-plugin:1.22 github:1.21.1 jquery-detached:1.2.1 github-oauth:0.24 scm-api:1.2 mapdb-api:1.0.9.0 pam-auth:1.3 workflow-basic-steps:2.1 pipeline-graph-analysis:1.1 repository-connector:1.1.3

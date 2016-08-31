# Useful:
#   http://www.catosplace.net/blog/2015/02/11/running-jenkins-in-docker-containers/
#   https://github.com/jenkinsci/docker#preinstalling-plugins
#   https://engineering.riotgames.com/news/jenkins-docker-proxies-and-compose

#FROM jenkins:2.7.1
FROM jenkinsci/jenkins:2.20
MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY seed/init.groovy /usr/share/jenkins/ref/init.groovy
COPY seed/jenkins-pipeline.groovy /usr/share/jenkins/jenkins-pipeline.groovy

USER jenkins

#COPY plugins.txt /usr/share/jenkins/plugins.txt
COPY fixed-install-plugins.sh /usr/local/bin/fixed-install-plugins.sh

RUN fixed-install-plugins.sh greenballs mask-passwords heavy-job credentials workflow-job credentials-binding envinject jobConfigHistory nested-view ant subversion rebuild junit groovy discard-old-build build-monitor-plugin github-organization-folder gradle pipeline-build-step token-macro cloudbees-folder parameterized-trigger dashboard-view plain-credentials maven-plugin git job-dsl:1.48 build-pipeline-plugin github cloudfoundry next-build-number github-oauth build-name-setter extra-columns jenkins-multijob-plugin pipeline-stage-view delivery-pipeline-plugin conditional-buildstep  thinBackup

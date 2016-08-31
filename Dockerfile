# Useful:
#   http://www.catosplace.net/blog/2015/02/11/running-jenkins-in-docker-containers/
#   https://github.com/jenkinsci/docker#preinstalling-plugins
#   https://engineering.riotgames.com/news/jenkins-docker-proxies-and-compose

FROM jenkins:2.0
MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY seed/init.groovy /usr/share/jenkins/ref/init.groovy
COPY seed/jenkins-pipeline-empty.groovy /usr/share/jenkins/jenkins-pipeline-empty.groovy
COPY seed/jenkins-pipeline-sample.groovy /usr/share/jenkins/jenkins-pipeline-sample.groovy

COPY plugins.txt /usr/share/jenkins/plugins.txt
RUN /usr/local/bin/plugins.sh /usr/share/jenkins/plugins.txt

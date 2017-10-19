# Useful:
#   http://www.catosplace.net/blog/2015/02/11/running-jenkins-in-docker-containers/
#   https://github.com/jenkinsci/docker#preinstalling-plugins
#   https://engineering.riotgames.com/news/jenkins-docker-proxies-and-compose

FROM jenkins:2.19.1
ARG gituser=changeme
ARG gitpass=changeme
ARG dockerRegistryOrg=changeme
ARG dockerRegistryUser=changeme
ARG dockerRegistryPass=changeme
ARG dockerRegistryEmail=changeme

MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY seed/init.groovy /usr/share/jenkins/ref/init.groovy
COPY seed/jenkins_pipeline.groovy /usr/share/jenkins/jenkins_pipeline.groovy
COPY seed/settings.xml /usr/share/jenkins/settings.xml
COPY plugins.txt /usr/share/jenkins/plugins.txt
COPY seed/k8s/* /usr/share/jenkins/cert/

USER root

# Generated via `start.sh`. If you don't want to provide it just put empty
# files there
RUN printf "%s" "${gituser}" > /usr/share/jenkins/gituser && \
    printf "%s" "${gitpass}" > /usr/share/jenkins/gitpass && \
    printf "%s" "${gitsshkey}" > /usr/share/jenkins/gitsshkey && \
    printf "%s" "${dockerRegistryUser}" > /usr/share/jenkins/dockerRegistryUser && \
    printf "%s" "${dockerRegistryPass}" > /usr/share/jenkins/dockerRegistryPass && \
    printf "%s" "${dockerRegistryEmail}" > /usr/share/jenkins/dockerRegistryEmail

RUN chmod 400 /usr/share/jenkins/gitsshkey

# Default mysql credentials - you can modify them as you please. You can
# parametrize them so that values are not hardcoded
RUN printf "%s" "rootpassword" > /usr/share/jenkins/mySqlRootPass && \
    printf "%s" "username" > /usr/share/jenkins/mySqlPass && \
    printf "%s" "password" > /usr/share/jenkins/mySqlUser

USER root

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false \
              -Djava.awt.headless=true \
              -Dhudson.model.ParametersAction.keepUndefinedParameters=true

# Install libs needed by the master worker for building apps
RUN apt-get update && \
    apt-get install -y ruby curl jq && \
    apt-get clean

# Install cf-cli
RUN apt-get -y install apt-transport-https && \
    wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | apt-key add - && \
    echo "deb http://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list && \
    apt-get -y update && \
    apt-get -y install cf-cli

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

# Making docker in docker possible
USER root
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get -y install apt-transport-https ca-certificates && \
    echo "deb https://apt.dockerproject.org/repo debian-jessie main" | tee /etc/apt/sources.list.d/docker.list && \
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install --assume-yes docker-engine && \
    echo "jenkins ALL=NOPASSWD: /usr/bin/docker" >> /etc/sudoers && \
    echo "jenkins ALL=NOPASSWD: /usr/local/bin/docker-compose" >> /etc/sudoers && \
    echo 'Defaults  env_keep += "HOME"' >> /etc/sudoers

# You can use Jenkins API to generate the list of plugins from a running
# Jenkins instance:
#
#  $ JENKINS_URL="http://user:pass@localhost:8080"
#  $ curl -sSL "${JENKINS_URL}/pluginManager/api/json?depth=1" | \
#    jq -r '.plugins[] | .shortName +":"+ .version' | sort > plugins.txt
#
RUN install-plugins.sh $( paste -sd' ' /usr/share/jenkins/plugins.txt )

# Useful:
#   http://www.catosplace.net/blog/2015/02/11/running-jenkins-in-docker-containers/
#   https://github.com/jenkinsci/docker#preinstalling-plugins
#   https://engineering.riotgames.com/news/jenkins-docker-proxies-and-compose

FROM jenkins/jenkins:2.130

LABEL maintainer "Marcin Grzejszczak <mgrzejszczak@pivotal.io>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV ANSIBLE_VERSION 2.6.3
ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false \
              -Djava.awt.headless=true \
              -Dhudson.model.ParametersAction.keepUndefinedParameters=true \
              -Dpermissive-script-security.enabled=no_security

ARG gituser=changeme
ARG gitpass=changeme
ARG gitsshkey=
ARG dockerRegistryOrg=changeme
ARG dockerRegistryUser=changeme
ARG dockerRegistryPass=changeme
ARG dockerRegistryEmail=changeme

COPY seed/init.groovy /usr/share/jenkins/ref/init.groovy
COPY seed/jenkins_pipeline.groovy /usr/share/jenkins/jenkins_pipeline.groovy
COPY seed/settings.xml /usr/share/jenkins/settings.xml
COPY plugins.txt /usr/share/jenkins/plugins.txt
COPY seed/k8s/* /usr/share/jenkins/cert/

USER root

# Generated via `start.sh`. If you don't want to provide it just put empty
# files there
RUN echo -n "${gituser}" > /usr/share/jenkins/gituser && \
    echo -n "${gitpass}" > /usr/share/jenkins/gitpass && \
    echo -n "${gitsshkey}" > /usr/share/jenkins/gitsshkey && \
    echo -n "${dockerRegistryUser}" > /usr/share/jenkins/dockerRegistryUser && \
    echo -n "${dockerRegistryPass}" > /usr/share/jenkins/dockerRegistryPass && \
    echo -n "${dockerRegistryEmail}" > /usr/share/jenkins/dockerRegistryEmail && \
    chmod 400 /usr/share/jenkins/gitsshkey

# Default mysql credentials - you can modify them as you please. You can
# parametrize them so that values are not hardcoded
RUN echo -n rootpassword > /usr/share/jenkins/mySqlRootPass && \
    echo -n username > /usr/share/jenkins/mySqlPass && \
    echo -n password > /usr/share/jenkins/mySqlUser

# Install tools needed by the master worker for building apps
RUN apt-get update && \
    apt-get install -y --no-install-recommends ruby curl jq apt-transport-https ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install cf-cli
RUN curl -sL https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | apt-key add - && \
    echo "deb https://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends cf-cli && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN KUBERNETES_VERSION="$( curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt )" && \
    curl -o /usr/local/bin/kubectl -LO "https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl" && \
    chmod 755 /usr/local/bin/kubectl

# Install Ansible
RUN apt-get update && \
    apt-get install -y --no-install-recommends python-dev python-pip python-setuptools && \
    pip install --no-cache-dir ansible==${ANSIBLE_VERSION} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Making docker in docker possible
RUN echo "deb https://apt.dockerproject.org/repo debian-jessie main" | tee /etc/apt/sources.list.d/docker.list && \
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-engine && \
    echo "jenkins ALL=NOPASSWD: /usr/bin/docker" >> /etc/sudoers && \
    echo "jenkins ALL=NOPASSWD: /usr/local/bin/docker-compose" >> /etc/sudoers && \
    echo 'Defaults  env_keep += "HOME"' >> /etc/sudoers && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# You can use Jenkins API to generate the list of plugins from a running
# Jenkins instance:
#
#  $ JENKINS_URL="https://user:pass@localhost:8080"
#  $ curl -sSL "${JENKINS_URL}/pluginManager/api/json?depth=1" | \
#    jq -r '.plugins[] | .shortName +":"+ .version' | sort > plugins.txt
#
RUN install-plugins.sh $( paste -sd' ' /usr/share/jenkins/plugins.txt )

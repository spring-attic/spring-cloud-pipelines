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
COPY plugins.txt /usr/share/jenkins/plugins.txt
COPY seed/k8s/* /usr/share/jenkins/cert/

USER root

# Generated via `start.sh`. If you don't want to provide it just put empty
# files there
RUN printf "%s" "${gituser}" > /usr/share/jenkins/gituser
RUN printf "%s" "${gitpass}" > /usr/share/jenkins/gitpass

USER root

ENV JAVA_OPTS -Djenkins.install.runSetupWizard=false \
              -Djava.awt.headless=true \
              -Dhudson.model.ParametersAction.keepUndefinedParameters=true

RUN apt-get update && \
    apt-get install -y ruby curl && \
    apt-get clean

# Install cf-cli
RUN apt-get -y install apt-transport-https
RUN wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | apt-key add -
RUN echo "deb http://packages.cloudfoundry.org/debian stable main" | tee /etc/apt/sources.list.d/cloudfoundry-cli.list
RUN apt-get -y update
RUN apt-get -y install cf-cli

# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

RUN apt-get update
RUN apt-get install -y apt-transport-https ca-certificates curl tar \
                    gnupg2 software-properties-common python-software-properties \
                    btrfs-progs e2fsprogs iptables

# Installing Docker for Kubernetes builds
# https://docs.docker.com/engine/installation/linux/docker-ce/debian/#install-using-the-repository

# https://github.com/docker/docker/blob/master/project/PACKAGERS.md#runtime-dependencies
# TODO aufs-tools

# set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
RUN set -x \
	&& addgroup --system dockremap \
	&& adduser --system --ingroup dockremap dockremap \
	&& echo 'dockremap:165536:65536' >> /etc/subuid \
	&& echo 'dockremap:165536:65536' >> /etc/subgid

ENV DIND_COMMIT 3b5fac462d21ca164b3778647420016315289034

RUN set -ex; \
	wget -O /usr/local/bin/dind "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind"; \
	chmod +x /usr/local/bin/dind; \

COPY dockerd-entrypoint.sh /usr/local/bin/
RUN /usr/local/bin/dockerd-entrypoint.sh

VOLUME /var/lib/docker
EXPOSE 2375

USER jenkins

# You can use Jenkins API to generate the list of plugins from a running
# Jenkins instance:
#
#  $ JENKINS_URL="http://user:pass@localhost:8080"
#  $ curl -sSL "${JENKINS_URL}/pluginManager/api/json?depth=1" | \
#    jq -r '.plugins[] | .shortName +":"+ .version' | sort > plugins.txt
#
RUN install-plugins.sh $( paste -sd' ' /usr/share/jenkins/plugins.txt )

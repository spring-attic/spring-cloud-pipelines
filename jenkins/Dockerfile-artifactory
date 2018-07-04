FROM docker.bintray.io/jfrog/artifactory-oss:6.1.0

MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY artifactory.config.import.yml /var/opt/jfrog/artifactory/etc/artifactory.config.import.yml

ENTRYPOINT ["/bin/sh", "-c", "/entrypoint-artifactory.sh"]

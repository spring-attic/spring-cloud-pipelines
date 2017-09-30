FROM docker.bintray.io/jfrog/artifactory-oss:5.5.1

MAINTAINER Marcin Grzejszczak <mgrzejszczak@pivotal.io>

COPY artifactory.config.import.yml /var/opt/jfrog/artifactory/etc/artifactory.config.import.yml

ENTRYPOINT ["/bin/sh", "-c", "/entrypoint-artifactory.sh"]

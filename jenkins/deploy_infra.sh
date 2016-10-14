#!/bin/bash
#The script will clone the infra repos and upload them to your artifactory
#You can provide 1 parameter - it's optional
#1 - folder to which the projects should be cloned. If not provided will use *build* folder
#Example: ./deploy_infra.sh
#Example: ./deploy_infra.sh ../repos/pivotal/

set -e

POTENTIAL_DOCKER_HOST=`echo $DOCKER_HOST | cut -d ":" -f 2 | cut -d "/" -f 3`

if [[ -z "${POTENTIAL_DOCKER_HOST}" ]]; then
    POTENTIAL_DOCKER_HOST="localhost"
fi

FOLDER=${1:-build}
CURRENT=`pwd`
mkdir -p ${FOLDER}
rm -rf "${CURRENT}/${FOLDER}/github-eureka"
rm -rf "${CURRENT}/${FOLDER}/github-analytics-stub-runner-boot"

echo "Docker is running at [${POTENTIAL_DOCKER_HOST}]"
echo "Folder to clone the apps is [${FOLDER}]"

echo "Deploying Eureka to Artifactory"
cd "${CURRENT}/${FOLDER}"
git clone https://github.com/spring-cloud-samples/github-eureka
cd github-eureka
./mvnw clean deploy -Ddistribution.management.release.url=http://${POTENTIAL_DOCKER_HOST}:8081/artifactory/libs-release-local

echo "Deploying Stub Runner to Artifactory"
cd "${CURRENT}/${FOLDER}"
git clone https://github.com/spring-cloud-samples/github-analytics-stub-runner-boot
cd github-analytics-stub-runner-boot
./mvnw clean deploy -Ddistribution.management.release.url=http://${POTENTIAL_DOCKER_HOST}:8081/artifactory/libs-release-local

echo "DONE!"

cd "${CURRENT}"
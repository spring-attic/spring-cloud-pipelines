#!/bin/bash

function usage {
	echo "usage: $0: <kill-all-apps|kill-all-prod-apps|delete-all-apps\
|delete-all-test-apps|delete-all-stage-apps|delete-routes|delete-all-services\
|setup-spaces|setup-prod-infra>"
	exit 1
}

export REUSE_CF_LOGIN
REUSE_CF_LOGIN="${REUSE_CF_LOGIN:-false}"
export PAAS_TEST_ORG
PAAS_TEST_ORG="${PAAS_TEST_ORG:-pcfdev-org}"
export PAAS_STAGE_ORG
PAAS_STAGE_ORG="${PAAS_STAGE_ORG:-pcfdev-org}"
export PAAS_PROD_ORG
PAAS_PROD_ORG="${PAAS_PROD_ORG:-pcfdev-org}"
export PAAS_TEST_SPACE
PAAS_TEST_SPACE="${PAAS_TEST_SPACE:-pcfdev-test}"
export PAAS_STAGE_SPACE
PAAS_STAGE_SPACE="${PAAS_STAGE_SPACE:-pcfdev-stage}"
export PAAS_PROD_SPACE
PAAS_PROD_SPACE="${PAAS_PROD_SPACE:-pcfdev-prod}"
export APPLICATION_HOST
APPLICATION_HOST="${APPLICATION_HOST:-local.pcfdev.io}"
export CF_API_URL
CF_API_URL="${CF_API_URL:-api.local.pcfdev.io}"
export CF_USERNAME
CF_USERNAME="${CF_USERNAME:-admin}"
export CF_PASSWORD
CF_PASSWORD="${CF_PASSWORD:-admin}"
export CF_DEFAULT_ORG
CF_DEFAULT_ORG="${CF_DEFAULT_ORG:-pcfdev-org}"
export CF_DEFAULT_SPACE
CF_DEFAULT_SPACE="${CF_DEFAULT_SPACE:-pcfdev-test}"
export ARTIFACTORY_URL
ARTIFACTORY_URL="${ARTIFACTORY_URL:-https://repo.spring.io/libs-milestone}"
export EUREKA_MEMORY
EUREKA_MEMORY="${EUREKA_MEMORY:-1024m}"

function cf_login {
    if [[ "${REUSE_CF_LOGIN}" == "true" ]]; then
        echo "Reusing the current CF connection"
    else
        cf login -a "${CF_API_URL}" \
            --skip-ssl-validation \
            -u "${CF_USERNAME}" \
            -p "${CF_PASSWORD}" \
            -o "${CF_DEFAULT_ORG}" \
            -s "${CF_DEFAULT_SPACE}"
    fi
}

[[ $# -eq 1 ]] || usage

case $1 in
	kill-all-apps)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_TEST_ORG}" -s "${PAAS_TEST_SPACE}"
		fi
		yes | cf stop github-webhook
		yes | cf stop github-analytics
		yes | cf stop eureka-github-webhook
		yes | cf stop eureka-github-analytics
		yes | cf stop stubrunner
		yes | cf stop stubrunner-github-webhook
		yes | cf stop stubrunner-github-analytics

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_STAGE_ORG}" -s "${PAAS_STAGE_SPACE}"
		fi
		yes | cf stop github-webhook
		yes | cf stop github-analytics
		yes | cf stop github-eureka

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_PROD_ORG}" -s "${PAAS_PROD_SPACE}"
		fi
		yes | cf stop github-webhook
		yes | cf stop github-webhook-venerable
		yes | cf stop github-analytics
		yes | cf stop github-analytics-venerable
		yes | cf stop github-eureka
		;;

	kill-all-prod-apps)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_PROD_ORG}" -s "${PAAS_PROD_SPACE}"
		fi
		yes | cf stop github-webhook
		yes | cf stop github-webhook-venerable
		yes | cf stop github-analytics
		yes | cf stop github-analytics-venerable
		yes | cf stop github-eureka
		;;

	delete-all-apps)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_TEST_ORG}" -s "${PAAS_TEST_SPACE}"
		fi
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f eureka-github-analytics
		cf delete -f eureka-github-webhook
		cf delete -f stubrunner-github-webhook
		cf delete -f stubrunner-github-analytics

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_STAGE_ORG}" -s "${PAAS_STAGE_SPACE}"
		fi
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f github-eureka

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_PROD_ORG}" -s "${PAAS_PROD_SPACE}"
		fi
		cf delete -f github-webhook
		cf delete -f github-webhook-venerable
		cf delete -f github-analytics
		cf delete -f github-analytics-venerable
		cf delete -f github-eureka
		;;

	delete-all-test-apps)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_TEST_ORG}" -s "${PAAS_TEST_SPACE}"
		fi
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f eureka-github-webhook
		cf delete -f eureka-github-analytics
		cf delete -f stubrunner-github-webhook
		cf delete -f stubrunner-github-analytics
		;;

	delete-all-stage-apps)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_STAGE_ORG}" -s "${PAAS_STAGE_SPACE}"
		fi
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f github-eureka
		;;

	delete-routes)
		cf delete-route -f "${APPLICATION_HOST}" -n github-webhook-test
		cf delete-route -f "${APPLICATION_HOST}" -n github-analytics-test
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-webhook-test
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-analytics-test
		cf delete-route -f "${APPLICATION_HOST}" -n stubrunner-test
		cf delete-route -f "${APPLICATION_HOST}" -n stubrunner-github-webhook-test
		cf delete-route -f "${APPLICATION_HOST}" -n stubrunner-github-analytics-test
		cf delete-route -f "${APPLICATION_HOST}" -n github-webhook-stage
		cf delete-route -f "${APPLICATION_HOST}" -n github-analytics-stage
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-webhook-stage
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-analytics-stage
		cf delete-route -f "${APPLICATION_HOST}" -n github-analytics
		cf delete-route -f "${APPLICATION_HOST}" -n github-webhook
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-webhook
		cf delete-route -f "${APPLICATION_HOST}" -n eureka-github-analytics
		;;

	setup-spaces)
		cf_login

		cf create-space "${PAAS_TEST_SPACE}"
		cf set-space-role user pcfdev-org "${PAAS_TEST_SPACE}" SpaceDeveloper

		cf create-space "${PAAS_STAGE_SPACE}"
		cf set-space-role user pcfdev-org "${PAAS_STAGE_SPACE}" SpaceDeveloper

		cf create-space "${PAAS_PROD_SPACE}"
		cf set-space-role user pcfdev-org "${PAAS_PROD_SPACE}" SpaceDeveloper
		;;

	delete-all-services)
		cf_login

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_TEST_ORG}" -s "${PAAS_TEST_SPACE}"
		fi
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github-webhook
		yes | cf delete-service -f rabbitmq-github-analytics
		yes | cf delete-service -f eureka-github-webhook
		yes | cf delete-service -f eureka-github-analytics

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_STAGE_ORG}" -s "${PAAS_STAGE_SPACE}"
		fi
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github
		yes | cf delete-service -f mysql-github
		yes | cf delete-service -f github-eureka

		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -o "${PAAS_PROD_ORG}" -s "${PAAS_PROD_SPACE}"
		fi
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github
		yes | cf delete-service -f mysql-github
		yes | cf delete-service -f github-eureka
		;;

	setup-prod-infra)
		cf_login
		if [[ "${REUSE_CF_LOGIN}" != "true" ]]; then
			cf target -s "${PAAS_PROD_SPACE}"
		fi
		echo "Installing rabbitmq"
		cf cs p-rabbitmq standard github-rabbitmq || cf cs cloudamqp lemur github-rabbimq
		echo "Installing mysql"
		cf cs p-mysql 512mb mysql-github-analytics || cf cs p-mysql 100mb mysql-github-analytics
		echo "Downloading eureka jar from ${ARTIFACTORY_URL}"
		mkdir -p build
		curl "${ARTIFACTORY_URL}/com/example/eureka/github-eureka/0.0.1.M1/github-eureka-0.0.1.M1.jar" -o "build/eureka.jar" --fail || echo "Failed to download the JAR"
		echo "Deploying eureka"
		cf push "github-eureka" -p "build/eureka.jar" -n "github-eureka" -b "https://github.com/cloudfoundry/java-buildpack.git#v3.8.1" -m "${EUREKA_MEMORY}" -i 1 --no-manifest --no-start
		APPLICATION_DOMAIN="$( cf apps | grep github-eureka | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1 )"
		JSON='{"uri":"http://'${APPLICATION_DOMAIN}'"}'
		cf set-env "github-eureka" 'APPLICATION_DOMAIN' "${APPLICATION_DOMAIN}"
		cf set-env "github-eureka" 'JAVA_OPTS' '-Djava.security.egd=file:///dev/urandom'
		cf restart "github-eureka"
		cf create-user-provided-service "github-eureka" -p "${JSON}" || echo "Service already created. Proceeding with the script"
		;;

	*)
		usage
		;;
esac

#!/bin/bash

function usage {
	echo "usage: $0: <kill-all-apps|kill-all-prod-apps|delete-all-apps\
|delete-all-test-apps|delete-all-stage-apps|delete-routes|delete-all-services\
|setup-spaces|setup-prod-infra>"
	exit 1
}

function pcfdev_login {
	cf login -a https://api.local.pcfdev.io \
		--skip-ssl-validation \
		-u admin \
		-p admin \
		-o pcfdev-org \
		-s pcfdev-test
}

[[ $# -eq 1 ]] || usage

case $1 in
	kill-all-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-test
		yes | cf stop github-webhook
		yes | cf stop github-analytics
		yes | cf stop eureka-github-webhook
		yes | cf stop eureka-github-analytics
		yes | cf stop stubrunner
		yes | cf stop stubrunner-github-webhook
		yes | cf stop stubrunner-github-analytics

		cf target -o pcfdev-org -s pcfdev-stage
		yes | cf stop github-webhook
		yes | cf stop github-analytics
		yes | cf stop github-eureka

		cf target -o pcfdev-org -s pcfdev-prod
		yes | cf stop github-webhook
		yes | cf stop github-webhook-venerable
		yes | cf stop github-analytics
		yes | cf stop github-analytics-venerable
		yes | cf stop github-eureka
		;;

	kill-all-prod-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-prod
		yes | cf stop github-webhook
		yes | cf stop github-webhook-venerable
		yes | cf stop github-analytics
		yes | cf stop github-analytics-venerable
		yes | cf stop github-eureka
		;;

	delete-all-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-test
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f eureka-github-analytics
		cf delete -f eureka-github-webhook
		cf delete -f stubrunner-github-webhook
		cf delete -f stubrunner-github-analytics

		cf target -o pcfdev-org -s pcfdev-stage
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f github-eureka

		cf target -o pcfdev-org -s pcfdev-prod
		cf delete -f github-webhook
		cf delete -f github-webhook-venerable
		cf delete -f github-analytics
		cf delete -f github-analytics-venerable
		cf delete -f github-eureka
		;;

	delete-all-test-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-test
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f eureka-github-webhook
		cf delete -f eureka-github-analytics
		cf delete -f stubrunner-github-webhook
		cf delete -f stubrunner-github-analytics
		;;

	delete-all-stage-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-stage
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f github-eureka
		;;

	delete-routes)
		cf delete-route -f local.pcfdev.io -n github-webhook-test
		cf delete-route -f local.pcfdev.io -n github-analytics-test
		cf delete-route -f local.pcfdev.io -n eureka-github-webhook-test
		cf delete-route -f local.pcfdev.io -n eureka-github-analytics-test
		cf delete-route -f local.pcfdev.io -n stubrunner-test
		cf delete-route -f local.pcfdev.io -n stubrunner-github-webhook-test
		cf delete-route -f local.pcfdev.io -n stubrunner-github-analytics-test
		cf delete-route -f local.pcfdev.io -n github-webhook-stage
		cf delete-route -f local.pcfdev.io -n github-analytics-stage
		cf delete-route -f local.pcfdev.io -n eureka-github-webhook-stage
		cf delete-route -f local.pcfdev.io -n eureka-github-analytics-stage
		cf delete-route -f local.pcfdev.io -n github-analytics
		cf delete-route -f local.pcfdev.io -n github-webhook
		cf delete-route -f local.pcfdev.io -n eureka-github-webhook
		cf delete-route -f local.pcfdev.io -n eureka-github-analytics
		;;

	setup-spaces)
		pcfdev_login

		cf create-space pcfdev-test
		cf set-space-role user pcfdev-org pcfdev-test SpaceDeveloper

		cf create-space pcfdev-stage
		cf set-space-role user pcfdev-org pcfdev-stage SpaceDeveloper

		cf create-space pcfdev-prod
		cf set-space-role user pcfdev-org pcfdev-prod SpaceDeveloper
		;;

	delete-all-services)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-test
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github-webhook
		yes | cf delete-service -f rabbitmq-github-analytics
		yes | cf delete-service -f eureka-github-webhook
		yes | cf delete-service -f eureka-github-analytics

		cf target -o pcfdev-org -s pcfdev-stage
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github
		yes | cf delete-service -f mysql-github
		yes | cf delete-service -f github-eureka

		cf target -o pcfdev-org -s pcfdev-prod
		yes | cf delete-service -f mysql-github-webhook
		yes | cf delete-service -f mysql-github-analytics
		yes | cf delete-service -f rabbitmq-github
		yes | cf delete-service -f mysql-github
		yes | cf delete-service -f github-eureka
		;;

	setup-prod-infra)
		pcfdev_login
		cf target -s pcfdev-prod

		POTENTIAL_DOCKER_HOST="$( echo "${DOCKER_HOST}" | cut -d ":" -f 2 | cut -d "/" -f 3 )"
		if [[ -z "${POTENTIAL_DOCKER_HOST}" ]]; then
			POTENTIAL_DOCKER_HOST="localhost"
		fi
		ARTIFACTORY_URL="${ARTIFACTORY_URL:-http://admin:password@${POTENTIAL_DOCKER_HOST}:8081/artifactory/libs-release-local}"
		ARTIFACTORY_ID="${ARTIFACTORY_ID:-artifactory-local}"

		echo "Installing rabbitmq" && cf cs p-rabbitmq standard github-rabbitmq
		# for Standard CF
		# cf cs cloudamqp lemur
		echo "Installing mysql" && cf cs p-mysql 512mb "mysql-github-analytics"
		# for Standard CF
		# cf cs p-mysql 100mb
		echo "Downloading eureka jar"
		mkdir -p build
		curl "${ARTIFACTORY_URL}/com/example/eureka/github-eureka/0.0.1.M1/github-eureka-0.0.1.M1.jar" -o "build/eureka.jar" --fail
		echo "Deploying eureka"
		cf push "github-eureka" -p "build/eureka.jar" -n "github-eureka" -b "https://github.com/cloudfoundry/java-buildpack.git#v3.8.1" -m "256m" -i 1 --no-manifest --no-start
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

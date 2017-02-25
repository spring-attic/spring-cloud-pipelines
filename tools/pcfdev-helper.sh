#!/bin/bash

function usage {
	echo "usage: $0: <kill-all-apps|delete-all-apps|delete-routes|setup-spaces>"
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
		yes | cf stop github-eureka
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

	delete-all-apps)
		pcfdev_login

		cf target -o pcfdev-org -s pcfdev-test
		cf delete -f github-webhook
		cf delete -f github-analytics
		cf delete -f github-eureka
		cf delete -f stubrunner

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

	delete-routes)
		cf delete-route -f local.pcfdev.io -n github-webhook-test
		cf delete-route -f local.pcfdev.io -n github-analytics-test
		cf delete-route -f local.pcfdev.io -n github-eureka-test
		cf delete-route -f local.pcfdev.io -n stubrunner-test
		cf delete-route -f local.pcfdev.io -n stubrunner-github-webhook-test
		cf delete-route -f local.pcfdev.io -n stubrunner-github-analytics-test
		cf delete-route -f local.pcfdev.io -n github-webhook-stage
		cf delete-route -f local.pcfdev.io -n github-analytics-stage
		cf delete-route -f local.pcfdev.io -n github-eureka-stage
		cf delete-route -f local.pcfdev.io -n github-analytics
		cf delete-route -f local.pcfdev.io -n github-webhook
		cf delete-route -f local.pcfdev.io -n github-eureka
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

	*)
		usage
		;;
esac


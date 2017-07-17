#!/bin/bash

function usage {
	echo "usage: $0: <download-kubectl|download-minikube|delete-all-apps|delete-all-test-apps|delete-all-stage-apps|delete-all-prod-apps>"
	exit 1
}

function system {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine=linux;;
        Darwin*)    machine=darwin;;
        *)          echo "Unsupported system" && exit 1
    esac
    echo ${machine}
}

SYSTEM=$( system )

[[ $# -eq 1 ]] || usage

case $1 in
	download-kubectl)
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/${SYSTEM}/amd64/kubectl
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
        ;;

	download-minikube)
		curl -Lo minikube https://storage.googleapis.com/minikube/releases/v0.20.0/minikube-${SYSTEM}-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
		;;

	delete-all-apps)
		kubectl delete pods,deployments,services,persistentvolumeclaims,secrets --all
		;;

	delete-all-test-apps)
		kubectl delete pods,deployments,services,persistentvolumeclaims,secrets --all -l environment=test
		;;

	delete-all-stage-apps)
		kubectl delete pods,deployments,services,persistentvolumeclaims,secrets --all -l environment=stage
		;;

	delete-all-prod-apps)
		kubectl delete pods,deployments,services,persistentvolumeclaims,secrets --all -l environment=prod
		;;

	*)
		usage
		;;
esac

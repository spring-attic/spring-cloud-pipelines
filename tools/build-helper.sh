#!/bin/bash

function usage {
	echo "usage: $0: <download-shellcheck>"
	exit 1
}

function system {
	unameOut="$(uname -s)"
	case "${unameOut}" in
		Linux*)	 machine=linux;;
		Darwin*)	machine=darwin;;
		*)		  echo "Unsupported system" && exit 1
	esac
	echo ${machine}
}


SYSTEM=$( system )

[[ $# -eq 1 ]] || usage

export ROOT_FOLDER="`pwd`../"
export FOLDER="`pwd`/"
if [ -d "tools" ]; then
	FOLDER="`pwd`/tools/"
	ROOT_FOLDER="`pwd`/"
fi

case $1 in
	download-shellcheck)
		if [[ "${SYSTEM}" == "linux" ]]; then
		# Download
		wget -P "${FOLDER}/build/" https://storage.googleapis.com/shellcheck/shellcheck-latest.linux.x86_64.tar.xz
		# Extract
		tar xvf "${FOLDER}/build/shellcheck-latest.linux.x86_64.tar.xz" -C "${FOLDER}/build"
		# Make it globally available
		sudo cp "${FOLDER}/build/shellcheck-latest/shellcheck" /usr/bin/shellcheck || echo "Failed to copy shellcheck"
		elif [[ "${SYSTEM}" == "darwin" ]]; then
			brew install shellcheck
		fi
		;;
	*)
		usage
		;;
esac

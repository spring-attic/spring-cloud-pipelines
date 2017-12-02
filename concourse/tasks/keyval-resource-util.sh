#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

function exportKeyValProperties() {
	props="${ROOT_FOLDER}/${KEYVAL_RESOURCE}/keyval.properties"
	if [ -f "$props" ]
	then
	  echo "Reading passed key values"
	  while IFS= read -r var
	  do
	    if [ ! -z "$var" ]
	    then
	      echo "Adding: $var"
	      export "$var"
	    fi
	  done < "$props"
	fi
}


function passKeyValProperties() {
	propsDir="${ROOT_FOLDER}/${KEYVALOUTPUT_RESOURCE}"
	propsFile="${propsDir}/keyval.properties"
	if [ -d "$propsDir" ]
	then
	  touch "$propsFile"
	  echo "Setting key values for next job in ${propsFile}"
	  while IFS='=' read -r name value ; do
	    if [[ $name == 'PASSED_'* ]]; then
	      echo "Adding: ${name}=${value}"
	      echo "${name}=${value}" >> "$propsFile"
	    fi
	  done < <(env)
	fi
}

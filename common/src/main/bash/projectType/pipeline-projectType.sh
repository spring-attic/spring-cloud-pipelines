#!/bin/bash

set -o errexit
set -o errtrace
set -o pipefail

# synopsis {{{
# Script that knows how to define the type of the project.
# Scans for presence of files or the language type configuration.
# }}}

# FUNCTION: getLanguageType {{{
# Gets the language type from the parsed descriptor. Returns empty if it's not present
# or if [language_type] node is not present in the descriptor.
# Uses [PARSER_YAML] env var
function getLanguageType() {
	if [[ ! -z "${PARSED_YAML}" ]]; then
		local languageType
		languageType="$( echo "${PARSED_YAML}" | jq -r '.language_type' )"
		if [[ "${languageType}" == "null" ]]; then
			languageType=""
		fi
		echo "${languageType}"
	else
		echo ""
	fi
} # }}}

# FUNCTION: guessLanguageType {{{
# Tries to guess the language type basing on the contents of the repository
function guessLanguageType() {
	if [[ -f "mvnw" ||  -f "gradlew" ]]; then
		echo "jvm"
	elif [ -f "composer.json" ]; then
		echo "php"
	elif [ -f "package.json" ]; then
		echo "npm"
	elif ( ls ./*.sln 2>/dev/null 1>&2 ); then
		echo "dotnet"
	else
		echo ""
	fi
} # }}}

LANGUAGE_TYPE_FROM_DESCRIPTOR="$( getLanguageType )"

if [[ "${LANGUAGE_TYPE}" != "" ]]; then
	echo "Language type [${LANGUAGE_TYPE}] passed from env variables"
elif [[ "${LANGUAGE_TYPE_FROM_DESCRIPTOR}" != "" ]]; then
	LANGUAGE_TYPE="${LANGUAGE_TYPE_FROM_DESCRIPTOR}"
else
	echo "Language needs to be guessed from the sources"
	LANGUAGE_TYPE="$( guessLanguageType )"
	if [[ "${LANGUAGE_TYPE}" == "" ]]; then
		echo "Failed to guess the language type!"
		return 1
	fi
fi

echo "Language type [${LANGUAGE_TYPE}]"

# ---- [SOURCE] sourcing concrete language type ----
# shellcheck source=/dev/null
# Sources a file for the given [LANGUAGE_TYPE]
[[ -f "${__DIR}/projectType/pipeline-${LANGUAGE_TYPE}.sh" ]] && source "${__DIR}/projectType/pipeline-${LANGUAGE_TYPE}.sh" ||  \
 echo "No projectType/pipeline-${LANGUAGE_TYPE}.sh found"

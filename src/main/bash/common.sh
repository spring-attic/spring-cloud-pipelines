#!/usr/bin/env bash

function retrieve_current_branch() {
	# Code getting the name of the current branch. For master we want to publish as we did until now
	# http://stackoverflow.com/questions/1593051/how-to-programmatically-determine-the-current-checked-out-git-branch
	# If there is a branch already passed will reuse it - otherwise will try to find it
	CURRENT_BRANCH=${BRANCH}
	if [[ -z "${CURRENT_BRANCH}" ]] ; then
	  CURRENT_BRANCH="$(git symbolic-ref -q HEAD)"
	  CURRENT_BRANCH="${CURRENT_BRANCH##refs/heads/}"
	  CURRENT_BRANCH="${CURRENT_BRANCH:-HEAD}"
	fi
	echo "Current branch is [${CURRENT_BRANCH}]"
	git checkout "${CURRENT_BRANCH}" || echo "Failed to check the branch... continuing with the script"
	PREVIOUS_BRANCH="${CURRENT_BRANCH}"
}

# Switch back to the previous branch and exit block
function checkout_previous_branch() {
	git checkout "${PREVIOUS_BRANCH}" || echo "Failed to check the branch... continuing with the script"
	exit 0
}

package io.springframework.springio.common

import io.springframework.common.BuildAndDeploy

/**
 * @author Marcin Grzejszczak
 */
trait SpringIoJobs extends BuildAndDeploy {

	@Override
	String projectSuffix() {
		return 'spring-io'
	}

	String initializrName() {
		return "${projectSuffix()}-initializr"
	}
}
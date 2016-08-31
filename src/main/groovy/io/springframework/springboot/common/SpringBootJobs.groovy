package io.springframework.springboot.common

import io.springframework.common.BuildAndDeploy

/**
 * @author Marcin Grzejszczak
 */
trait SpringBootJobs extends BuildAndDeploy {

	@Override
	String projectSuffix() {
		return 'spring-boot'
	}

}
package org.springframework.cloud.pipelines.spinnaker.pipeline.model.cf

import groovy.transform.CompileStatic

/**
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class CloudFoundryManifest {
	int instances
	String memory
	String diskQuota
	String buildpack
	List<String> routes = []
	Map<String, String> env = [:]
	List<String> services = []
}


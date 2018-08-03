package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Manifest {
	String diskQuota
	List<Map<String, String>> env = []
	int instances
	String memory
	List<String> services = []
	String type
	List<String> routes
	String account
	String reference
}

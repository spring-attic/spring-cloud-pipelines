package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import java.util.List

import groovy.transform.CompileStatic

@CompileStatic
class Manifest {
	String diskQuota
	List<String> env = []
	int instances
	String memory
	List<String> services = []
	String type
}

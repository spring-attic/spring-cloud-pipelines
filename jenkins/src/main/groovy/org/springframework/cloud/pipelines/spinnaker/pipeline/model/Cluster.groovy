package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Cluster {
	String account
	String application
	Artifact artifact
	Capacity capacity
	String cloudProvider
	String detail
	Manifest manifest
	String provider
	String region
	String spaceId
	String stack
	String strategy
}

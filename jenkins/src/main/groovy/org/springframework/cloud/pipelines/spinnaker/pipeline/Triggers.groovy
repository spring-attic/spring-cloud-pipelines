package org.springframework.cloud.pipelines.spinnaker.pipeline

import groovy.transform.CompileStatic

@CompileStatic
class Triggers {
	String account
	String branch
	boolean enabled
	String job
	String master
	String organization
	PayloadConstraints payloadConstraints
	String project
	String registry
	String repository
	String slug
	String source
	String type
}

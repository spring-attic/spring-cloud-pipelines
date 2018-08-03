package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Trigger {
	String account
	String branch
	Boolean enabled
	String job
	String master
	String organization
	PayloadConstraints payloadConstraints
	String project
	String repository
	String slug
	String source
	String type
	String propertyFile
}

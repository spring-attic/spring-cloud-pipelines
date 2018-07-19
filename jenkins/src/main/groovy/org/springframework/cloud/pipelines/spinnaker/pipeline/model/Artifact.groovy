package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Artifact {
	String account
	String reference
	String pattern
	String type
}

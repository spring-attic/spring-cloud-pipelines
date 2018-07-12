package org.springframework.cloud.pipelines.spinnaker.pipeline

import groovy.transform.CompileStatic

@CompileStatic
class Artifact {
	String account
	String pattern
	String type
}

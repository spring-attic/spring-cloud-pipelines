package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Capacity {
	String desired
	String max
	String min
}

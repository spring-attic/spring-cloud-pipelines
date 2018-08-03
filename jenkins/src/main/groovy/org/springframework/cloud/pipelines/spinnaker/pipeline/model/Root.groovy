package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Root {
	AppConfig appConfig = new AppConfig()
	boolean keepWaitingPipelines
	boolean limitConcurrent = true
	List<Stage> stages = []
	List<Trigger> triggers = []
}

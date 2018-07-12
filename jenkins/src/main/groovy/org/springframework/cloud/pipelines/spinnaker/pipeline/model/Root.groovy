package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Root {
	AppConfig appConfig
	List<String> expectedArtifacts = []
	boolean keepWaitingPipelines
	String lastModifiedBy
	boolean limitConcurrent
	List<Stage> stages = []
	List<Trigger> triggers = []
	String updateTs
}

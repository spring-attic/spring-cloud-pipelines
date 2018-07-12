package org.springframework.cloud.pipelines.spinnaker.pipeline

import java.util.List

import groovy.transform.CompileStatic

@CompileStatic
class Root {
	AppConfig appConfig
	List<String> expectedArtifacts = []
	boolean keepWaitingPipelines
	String lastModifiedBy
	boolean limitConcurrent
	List<Stages> stages = []
	List<Triggers> triggers = []
	String updateTs
}

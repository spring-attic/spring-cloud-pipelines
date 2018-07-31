package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Stage {
	List<Cluster> clusters
	Boolean failPipeline
	String name
	String refId
	List<String> requisiteStageRefIds = []
	String type
	String command
	String scriptPath
	String user
	Boolean waitForCompletion
	Map<String, String> parameters
	String master
	String job
	List<String> judgmentInputs
	List<String> notifications
	Boolean continuePipeline
	Integer waitTime
	StageEnabled stageEnabled
}

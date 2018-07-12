package org.springframework.cloud.pipelines.spinnaker.pipeline.model

import groovy.transform.CompileStatic

@CompileStatic
class Stage {
	List<Cluster> clusters = []
	String name
	String refId
	List<String> requisiteStageRefIds = []
	String type
	String command
	boolean failPipeline = true
	String scriptPath
	String user
	boolean waitForCompletion
	List<String> parameters = []
	String master
	String job
	List<String> judgmentInputs
	List<String> notifications
	boolean continuePipeline
}

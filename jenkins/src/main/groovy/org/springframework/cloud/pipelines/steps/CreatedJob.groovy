package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.Job

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class CreatedJob {
	final Job job
	final boolean autoNextJob

	CreatedJob(Job job, boolean autoNextJob) {
		this.job = job
		this.autoNextJob = autoNextJob
	}
}

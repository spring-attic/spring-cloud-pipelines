package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.Job

/**
 * Contains the created job and info whether the next
 * step should be automated or not
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
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

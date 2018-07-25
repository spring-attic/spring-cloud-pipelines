package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * Contract for generating all the jobs for a pipeline
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
interface PipelineJobsFactory {
	void allJobs(Coordinates coordinates, String pipelineVersion)
}

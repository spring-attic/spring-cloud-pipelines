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

	/**
	 * Builds all jobs for the deployment pipeline
	 *
	 * @param coordinates - coordinates of a repo for which the pipelines is to be built
	 * @param pipelineVersion - the deployment pipeline version
	 * @param additionalFiles - a map of file name to its contents retrieved from the repo
	 */
	void allJobs(Coordinates coordinates, String pipelineVersion, Map<String, String> additionalFiles)
}

package org.springframework.cloud.pipelines.common;

import javaposse.jobdsl.dsl.jobs.FreeStyleJob;

/**
 * Hook to customize the created jobs
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
interface JobCustomizer {

	/**
	 * Applicable to all jobs in the pipeline
	 */
	void customizeAll(FreeStyleJob job)

	/**
	 * Applicable to jobs from the {@code build} phase
	 */
	void customizeBuild(FreeStyleJob job)

	/**
	 * Applicable to jobs from the {@code test} phase
	 */
	void customizeTest(FreeStyleJob job)

	/**
	 * Applicable to jobs from the {@code stage} phase
	 */
	void customizeStage(FreeStyleJob job)

	/**
	 * Applicable to jobs from the {@code prod} phase
	 */
	void customizeProd(FreeStyleJob job)
}

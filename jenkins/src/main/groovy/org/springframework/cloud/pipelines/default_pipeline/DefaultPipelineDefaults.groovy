package org.springframework.cloud.pipelines.default_pipeline

import groovy.transform.CompileStatic

/**
 * Contains default values for names of jobs and views for the default
 * sc-pipelines approach (sc-pipelines deploys the apps)
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class DefaultPipelineDefaults {
	static String projectName(String gitRepoName) {
		return "${gitRepoName}-pipeline"
	}

	static String viewName(String gitRepoName) {
		return gitRepoName
	}
}

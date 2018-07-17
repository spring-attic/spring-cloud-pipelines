package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic

/**
 * Contains default values for names of jobs and views
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class SpinnakerDefaults {
	static String projectName(String gitRepoName) {
		return "spinnaker-${gitRepoName}-pipeline"
	}

	static String viewName(String gitRepoName) {
		return "spinnaker-${gitRepoName}"
	}
}

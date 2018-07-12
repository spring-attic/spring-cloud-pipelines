package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class SpinnakerDefaults {
	static String projectName(String gitRepoName) {
		return "spinnaker-${gitRepoName}-pipeline"
	}
}

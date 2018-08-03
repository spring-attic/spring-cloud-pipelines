package org.springframework.cloud.pipelines.common

import groovy.transform.Canonical
import groovy.transform.CompileStatic

import org.springframework.cloud.projectcrawler.Repository

/**
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
@Canonical
class GeneratedJobs {
	List<Repository> repositoriesForViews = []
	Map<String, Exception> errors = [:]

	boolean hasErrors() {
		return !errors.isEmpty()
	}
}

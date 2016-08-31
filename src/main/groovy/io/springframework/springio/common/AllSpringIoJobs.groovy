package io.springframework.springio.common

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class AllSpringIoJobs implements SpringIoJobs {
	public static final List<String> ALL_JOBS = ['initializr']

	/**
	 * Traits cannot be instantiated thus I'm creating a fake class to access the
	 * initializrName() method
	 */
	static String getInitializrName() {
		return new AllSpringIoJobs().initializrName()
	}
}

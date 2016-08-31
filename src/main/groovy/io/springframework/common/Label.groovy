package io.springframework.common

import groovy.transform.CompileStatic

/**
 * Contains labels to provide build restrictions
 *
 * @author Marcin Grzejszczak
 */
@CompileStatic
trait Label {
	String aws() {
		return 'ec2-0'
	}

	String windows() {
		return 'win2012'
	}
}
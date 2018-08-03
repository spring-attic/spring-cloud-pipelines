package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * Ways in which the tools repo can be fetched
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
enum RepoType {
	TARBALL, GIT

	static RepoType from(String string) {
		if (string.endsWith(".tar.gz")) return TARBALL
		return GIT
	}
}

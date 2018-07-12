package org.springframework.cloud.pipelines.common

/**
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
enum RepoType {
	TARBALL, GIT

	static RepoType from(String string) {
		if (string.endsWith(".tar.gz")) return TARBALL
		return GIT
	}
}

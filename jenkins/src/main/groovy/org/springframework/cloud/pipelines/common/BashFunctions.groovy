package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class BashFunctions {

	private final boolean gitUseSsh
	private final String gitUser
	private final String gitEmail

	BashFunctions(String gitUser, String gitEmail, boolean gitUseSsh) {
		this.gitUseSsh = gitUseSsh
		this.gitUser = gitUser
		this.gitEmail = gitEmail
	}

	BashFunctions(PipelineDefaults defaults) {
		this.gitUseSsh = defaults.gitUseSshKey()
		this.gitUser = defaults.gitName()
		this.gitEmail = defaults.gitEmail()
	}

	String setupGitCredentials(String repoUrl) {
		if (gitUseSsh) {
			return ""
		}
		String repoWithoutGit = repoUrl.startsWith("git@") ? repoUrl.substring("git@".length()) : repoUrl
		URI uri = URI.create(repoWithoutGit)
		String host = uri.getHost()
		return """\
				set +x
				tmpDir="\$(mktemp -d)"
				trap "{ rm -rf \${tmpDir}; }" EXIT
				git config user.name "${gitUser}"
				git config user.email "${gitEmail}"
				git config credential.helper "store --file=\${tmpDir}/gitcredentials"
				echo "https://\$${PipelineDefaults.GIT_USER_NAME_ENV_VAR}:\$${PipelineDefaults.GIT_PASSWORD_ENV_VAR}@${host}" > \${tmpDir}/gitcredentials
			"""
	}
}

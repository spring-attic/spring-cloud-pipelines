package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.RepoType

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class CommonSteps {

	private final PipelineDefaults defaults
	private final BashFunctions bashFunctions

	CommonSteps(PipelineDefaults defaults, BashFunctions bashFunctions) {
		this.defaults = defaults
		this.bashFunctions = new BashFunctions(defaults)
	}

	void defaultWrappers(WrapperContext wrapperContext) {
		wrapperContext.with {
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
		}
	}

	void defaultPublishers(PublisherContext publisherContext) {
		publisherContext.with {
			archiveJunit(defaults.testReports()) {
				allowEmptyResults()
			}
		}
	}

	void runStep(StepContext stepContext, String stepName) {
		stepContext.shell('''#!/bin/bash
		set -o errexit
		set -o errtrace
		set -o pipefail
		${WORKSPACE}/.git/tools/common/src/main/bash/''' + stepName)
	}

	void configureScm(ScmContext context, String repoId, String branchId) {
		context.git {
			remote {
				name('origin')
				url(repoId)
				branch(branchId)
				credentials(defaults.gitUseSshKey() ?
					defaults.gitSshCredentials() : defaults.gitCredentials())
			}
			extensions {
				wipeOutWorkspace()
				submoduleOptions {
					recursive()
				}
			}
		}
	}

	void downloadTools(StepContext context, String repoUrl) {
		context.shell(downloadToolsScript(repoUrl))
	}

	protected String downloadToolsScript(String repoUrl) {
		String script = """#!/bin/bash\n"""
		RepoType repoType = RepoType.from(defaults.toolsRepo())
		script = script + bashFunctions.setupGitCredentials(repoUrl)
		if (repoType == RepoType.TARBALL) {
			return script + """rm -rf .git/tools && mkdir -p .git/tools && pushd .git/tools && curl -Lk "${defaults.toolsRepo()}" -o pipelines.tar.gz && tar xf pipelines.tar.gz --strip-components 1 && popd"""
		}
		return script + """rm -rf .git/tools && git clone -b ${defaults.toolsBranch()} --single-branch ${defaults.toolsRepo()} .git/tools"""
	}
}

package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.RepoType

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
@PackageScope
class CommonSteps {

	private final PipelineDefaults defaults
	private final BashFunctions bashFunctions

	CommonSteps(PipelineDefaults defaults, BashFunctions bashFunctions) {
		this.defaults = defaults
		this.bashFunctions = bashFunctions ?: new BashFunctions(defaults)
	}

	void deliveryPipelineVersion(WrapperContext wrapperContext) {
		wrapperContext.with {
			deliveryPipelineVersion('${ENV,var="' + EnvironmentVariables.PIPELINE_VERSION_ENV_VAR + '"}', true)
		}
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
			if (defaults.gitUseSshKey()) sshAgent(defaults.gitSshCredentials())
		}
	}

	void defaultPublishers(PublisherContext publisherContext) {
		publisherContext.with {
			archiveJunit(defaults.testReports()) {
				allowEmptyResults()
			}
		}
	}

	void deployPublishers(PublisherContext publisherContext) {
		publisherContext.with {
			// remove::start[K8S]
			archiveArtifacts {
				pattern("**/build/**/k8s/*.yml")
				pattern("**/target/**/k8s/*.yml")
				// remove::start[CF]
				allowEmpty()
				// remove::end[CF]
			}
			// remove::end[K8S]
		}
	}

	void runNextJob(PublisherContext publisherContext, String nextJob, boolean automatic) {
		if (automatic) {
			publisherContext.with {
				downstreamParameterized {
					trigger(nextJob) {
						parameters {
							currentBuild()
							propertiesFile('${' + EnvironmentVariables.OUTPUT_FOLDER_ENV_VAR + '}/test.properties', false)
						}
						triggerWithNoParameters()
					}
				}
			}
		} else {
			publisherContext.with {
				buildPipelineTrigger(nextJob) {
					parameters {
						propertiesFile('${' + EnvironmentVariables.OUTPUT_FOLDER_ENV_VAR + '}/test.properties', false)
						currentBuild()
					}
				}
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
			branch(branchId)
			remote {
				name('origin')
				url(repoId)
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

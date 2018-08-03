package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileDynamic
import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import javaposse.jobdsl.dsl.Job
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.JobCustomizer
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.RepoType
import org.springframework.cloud.projectcrawler.RepositoryManagementBuilder

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class CommonSteps {

	private static final ServiceLoader<JobCustomizer> LOADED = ServiceLoader
		.load(JobCustomizer)

	private final PipelineDefaults defaults
	private final BashFunctions bashFunctions

	CommonSteps(PipelineDefaults defaults, BashFunctions bashFunctions) {
		this.defaults = defaults
		this.bashFunctions = bashFunctions ?: new BashFunctions(defaults)
	}

	String readScript(String scriptName) {
		return CommonSteps.getResource("/steps/${scriptName}").text
	}

	@CompileDynamic
	void gitEmail(Job job) {
		job.configure { def project ->
			// Adding user email and name here instead of global settings
			project / 'scm' / 'extensions' << 'hudson.plugins.git.extensions.impl.UserIdentity' {
				'email'(defaults.gitName())
				'name'(defaults.gitEmail())
			}
		}
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
				allowEmpty()
			}
			// remove::end[K8S]
			// remove::start[CF]
			archiveArtifacts {
				pattern("manifest.yml")
				allowEmpty()
			}
			// remove::end[CF]
		}
	}

	void runStep(StepContext stepContext, String stepName) {
		stepContext.shell(readScript(stepName))
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

	Iterable<JobCustomizer> customizers() {
		return LOADED
	}
}

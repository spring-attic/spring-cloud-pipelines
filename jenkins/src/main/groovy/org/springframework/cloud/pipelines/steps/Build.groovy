package org.springframework.cloud.pipelines.steps

import java.sql.Wrapper

import groovy.transform.CompileDynamic
import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class Build {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	Build(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = new BashFunctions(pipelineDefaults.gitCredentials(),
			pipelineDefaults.gitEmail(), pipelineDefaults.gitUseSshKey())
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	void step(String projectName, String pipelineVersion, Coordinates coordinates) {
		String gitRepoName = coordinates.gitRepoName
		String branchName = coordinates.branchName
		String fullGitRepo = coordinates.fullGitRepo
		dsl.job("${projectName}-build") {
			deliveryPipelineConfiguration('Build', 'Build and Upload')
			triggers {
				cron(pipelineDefaults.cronValue())
				githubPush()
			}
			wrappers {
				deliveryPipelineVersion(pipelineVersion, true)
				environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
				commonSteps.defaultWrappers((delegate as Closure).delegate as WrapperContext)
				if (pipelineDefaults.gitUseSshKey()) {
					sshAgent(pipelineDefaults.gitSshCredentials())
				}
				credentialsBinding {
					if (pipelineDefaults.repoWithBinariesCredentials()) {
						usernamePassword('M2_SETTINGS_REPO_USERNAME', 'M2_SETTINGS_REPO_PASSWORD',
							pipelineDefaults.repoWithBinariesCredentials())
					}
					if (pipelineDefaults.dockerCredentials()) {
						usernamePassword('DOCKER_USERNAME', 'DOCKER_PASSWORD',
							pipelineDefaults.dockerCredentials())
					}
					if (!pipelineDefaults.gitUseSshKey()) {
						usernamePassword(PipelineDefaults.GIT_USER_NAME_ENV_VAR, PipelineDefaults.GIT_PASSWORD_ENV_VAR,
							pipelineDefaults.gitCredentials())
					}
				}
			}
			jdk(pipelineDefaults.jdkVersion())
			scm {
				this.commonSteps.configureScm(delegate as ScmContext, fullGitRepo, branchName)
			}
			email(delegate as Job)
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				shell("""#!/bin/bash 
		set -o errexit
		set -o errtrace
		set -o pipefail
		${bashFunctions.setupGitCredentials(fullGitRepo)}
		${ if (pipelineDefaults.apiCompatibilityStep()) {
					return '''\
		echo "First running api compatibility check, so that what we commit and upload at the end is just built project"
		${WORKSPACE}/.git/tools/common/src/main/bash/build_api_compatibility_check.sh
		'''}
		}
		\${WORKSPACE}/.git/tools/common/src/main/bash/build_and_upload.sh
		""")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
				git {
					pushOnlyIfSuccess()
					tag('origin', "dev/${gitRepoName}/\${PIPELINE_VERSION}") {
						create()
						update()
					}
				}
			}
		}
	}

	@CompileDynamic
	protected email(Job job) {
		job.configure { def project ->
			// Adding user email and name here instead of global settings
			project / 'scm' / 'extensions' << 'hudson.plugins.git.extensions.impl.UserIdentity' {
				'email'(gitEmail)
				'name'(gitName)
			}
		}
	}
}

package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileDynamic
import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext
import javaposse.jobdsl.dsl.jobs.FreeStyleJob

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.JobCustomizer
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.StepEnabledChecker

/**
 * Build and api compatibility step
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class Build implements Step<FreeStyleJob> {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps
	private final String pipelineVersion

	Build(DslFactory dsl, PipelineDefaults pipelineDefaults, String pipelineVersion) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = pipelineDefaults.bashFunctions()
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
		this.pipelineVersion = pipelineVersion
	}

	static String stepName(String projectName) {
		return "${projectName}-build"
	}

	@Override
	CreatedJob step(String projectName, Coordinates coordinates, PipelineDescriptor descriptor) {
		String gitRepoName = coordinates.gitRepoName
		String branchName = coordinates.branchName
		String fullGitRepo = coordinates.fullGitRepo
		StepEnabledChecker checker = new StepEnabledChecker(descriptor, pipelineDefaults)
		FreeStyleJob job = dsl.job(stepName(projectName)) {
			deliveryPipelineConfiguration('Build', 'Build and Upload')
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			triggers {
				cron(pipelineDefaults.cronValue())
				githubPush()
			}
			wrappers {
				deliveryPipelineVersion(pipelineVersion, true)
				commonSteps.defaultWrappers(delegate as WrapperContext)
				credentialsBinding {
					if (pipelineDefaults.repoWithBinariesCredentials()) {
						usernamePassword(EnvironmentVariables.M2_SETTINGS_REPO_USERNAME_ENV_VAR,
							EnvironmentVariables.M2_SETTINGS_REPO_PASSWORD_ENV_VAR,
							pipelineDefaults.repoWithBinariesCredentials())
					}
					if (pipelineDefaults.dockerCredentials()) {
						usernamePassword(EnvironmentVariables.DOCKER_USERNAME_ENV_VAR, EnvironmentVariables.DOCKER_PASSWORD_ENV_VAR,
							pipelineDefaults.dockerCredentials())
					}
					if (!pipelineDefaults.gitUseSshKey()) {
						usernamePassword(EnvironmentVariables.GIT_USERNAME_ENV_VAR, EnvironmentVariables.GIT_PASSWORD_ENV_VAR,
							pipelineDefaults.gitCredentials())
					}
				}
			}
			jdk(pipelineDefaults.jdkVersion())
			scm {
				this.commonSteps.configureScm(delegate as ScmContext, fullGitRepo, branchName)
			}
			commonSteps.gitEmail(delegate as Job)
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				shell("""#!/bin/bash 
		set -o errexit
		set -o errtrace
		set -o pipefail
		${bashFunctions.setupGitCredentials(fullGitRepo)}
		${
					if (checker.apiCompatibilityStepSet()) {
						return '''\
		echo "First running api compatibility check, so that what we commit and upload at the end is just built project"
		. ${WORKSPACE}/.git/tools/common/src/main/bash/build_api_compatibility_check.sh
		'''
					}
					return ''
				}
		
		tmpDir="\$(mktemp -d)"
		trap "{ rm -rf \$tmpDir; }" EXIT
		echo "Creating a trigger.properties file in [\${tmpDir}]"
		cp \${OUTPUT_FOLDER}/trigger.properties \$tmpDir || echo "Failed to copy the trigger.properties file. Continuing with the script"
		
		echo "Running the build and upload script"
		. \${WORKSPACE}/.git/tools/common/src/main/bash/build_and_upload.sh

		echo "Output current build properties to output"
		cp \$tmpDir/trigger.properties \${OUTPUT_FOLDER}/trigger.properties
		echo "PIPELINE_VERSION=\${PIPELINE_VERSION}" >> "\${OUTPUT_FOLDER}/trigger.properties"
		""")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
				commonSteps.deployPublishers(delegate as PublisherContext)
				git {
					pushOnlyIfSuccess()
					tag('origin', "dev/${gitRepoName}/\${${EnvironmentVariables.PIPELINE_VERSION_ENV_VAR}}") {
						create()
						update()
					}
				}
				archiveArtifacts {
					pattern("**/build/libs/*.jar")
					pattern("**/build/libs/trigger.properties")
					pattern("**/target/*.jar")
					pattern("**/target/trigger.properties")
					allowEmpty()
				}
			}
		}
		customize(job)
		return new CreatedJob(job, autoNextJob(checker))
	}

	@Override void customize(FreeStyleJob job) {
		commonSteps.customizers().each {
			it.customizeAll(job)
			it.customizeBuild(job)
		}
	}

	private boolean autoNextJob(StepEnabledChecker checker) {
		if (checker.apiCompatibilityStepSet()) {
			return true
		} else if (checker.testStepSet()) {
			return true
		} else if (checker.stageStepSet()) {
			return checker.autoStageSet()
		}
		return checker.autoProdSet()
	}
}

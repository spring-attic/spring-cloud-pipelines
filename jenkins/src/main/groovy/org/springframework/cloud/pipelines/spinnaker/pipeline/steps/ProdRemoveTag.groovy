package org.springframework.cloud.pipelines.spinnaker.pipeline.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.Job
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.steps.CommonSteps
import org.springframework.cloud.pipelines.steps.CreatedJob
import org.springframework.cloud.pipelines.steps.Step

/**
 * Removes the production tag
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class ProdRemoveTag implements Step {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	ProdRemoveTag(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = pipelineDefaults.bashFunctions()
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	@Override
	CreatedJob step(String projectName, Coordinates coordinates, PipelineDescriptor descriptor) {
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		Job job = dsl.job("${projectName}-prod-env-remove-tag") {
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			wrappers {
				commonSteps.defaultWrappers(delegate as WrapperContext)
				credentialsBinding {
					if (!pipelineDefaults.gitUseSshKey()) usernamePassword(EnvironmentVariables.GIT_USERNAME_ENV_VAR,
						EnvironmentVariables.GIT_PASSWORD_ENV_VAR,
						pipelineDefaults.gitCredentials())
				}
			}
			scm {
				commonSteps.configureScm(delegate as ScmContext, fullGitRepo,
					"dev/${gitRepoName}/\${${EnvironmentVariables.PIPELINE_VERSION_ENV_VAR}}")
			}
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				shell("""#!/bin/bash
				set -o errexit
				set -o errtrace
				set -o pipefail
				
				${bashFunctions.setupGitCredentials(fullGitRepo)}
				
				export ENVIRONMENT=prod
				source \${WORKSPACE}/.git/tools/common/src/main/bash/pipeline.sh
				removeProdTag
""")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
				commonSteps.deployPublishers(delegate as PublisherContext)
			}
		}
		commonSteps.customizers().each {
			it.customizeAll(job)
			it.customizeProd(job)
		}
		return new CreatedJob(job, false)
	}
}

package org.springframework.cloud.pipelines.steps

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
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor

/**
 * Rolls back on production
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class ProdRollback implements Step<FreeStyleJob> {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	ProdRollback(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = pipelineDefaults.bashFunctions()
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	@Override
	CreatedJob step(String projectName, Coordinates coordinates, PipelineDescriptor descriptor) {
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		Job job = dsl.job("${projectName}-prod-env-rollback") {
			deliveryPipelineConfiguration('Prod', 'Rollback')
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			wrappers {
				commonSteps.defaultWrappers(delegate as WrapperContext)
				commonSteps.deliveryPipelineVersion(delegate as WrapperContext)
				credentialsBinding {
					if (!pipelineDefaults.gitUseSshKey()) usernamePassword(EnvironmentVariables.GIT_USERNAME_ENV_VAR,
						EnvironmentVariables.GIT_PASSWORD_ENV_VAR,
						pipelineDefaults.gitCredentials())
					// remove::start[CF]
					if (pipelineDefaults.cfProdCredentialId()) usernamePassword(
						EnvironmentVariables.PAAS_PROD_USERNAME_ENV_VAR,
						EnvironmentVariables.PAAS_PROD_PASSWORD_ENV_VAR,
						pipelineDefaults.cfProdCredentialId())
					// remove::end[CF]
					// remove::start[K8S]
					if (pipelineDefaults.k8sProdTokenCredentialId()) string(EnvironmentVariables.TOKEN_ENV_VAR,
						pipelineDefaults.k8sProdTokenCredentialId())
					// remove::end[K8S]
				}
			}
			scm {
				commonSteps.configureScm(delegate as ScmContext, fullGitRepo,
					"dev/${gitRepoName}/\${${EnvironmentVariables.PIPELINE_VERSION_ENV_VAR}}")
			}
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				commonSteps.runStep(delegate as StepContext, "prod_rollback.sh")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
				commonSteps.deployPublishers(delegate as PublisherContext)
			}
		}
		customize(job)
		return new CreatedJob(job, false)
	}

	@Override void customize(FreeStyleJob job) {
		commonSteps.customizers().each {
			it.customizeAll(job)
			it.customizeProd(job)
		}
	}
}

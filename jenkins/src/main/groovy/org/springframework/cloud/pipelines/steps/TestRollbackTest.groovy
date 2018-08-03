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
import org.springframework.cloud.pipelines.common.StepEnabledChecker

/**
 * Runs rollback tests on test
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class TestRollbackTest implements Step<FreeStyleJob> {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	TestRollbackTest(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = pipelineDefaults.bashFunctions()
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	@Override
	CreatedJob step(String projectName, Coordinates coordinates, PipelineDescriptor descriptor) {
		StepEnabledChecker checker = new StepEnabledChecker(descriptor, pipelineDefaults)
		if (checker.rollbackStepMissing()) {
			return null
		}
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		Job job = dsl.job("${projectName}-test-env-rollback-test") {
			deliveryPipelineConfiguration('Test', 'Tests on test latest prod version')
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			wrappers {
				commonSteps.defaultWrappers(delegate as WrapperContext)
				commonSteps.deliveryPipelineVersion(delegate as WrapperContext)
				credentialsBinding {
					// remove::start[CF]
					if (pipelineDefaults.cfTestCredentialId()) usernamePassword(
						EnvironmentVariables.PAAS_TEST_USERNAME_ENV_VAR,
						EnvironmentVariables.PAAS_TEST_PASSWORD_ENV_VAR,
						pipelineDefaults.cfTestCredentialId())
					// remove::end[CF]
					// remove::start[K8S]
					if (pipelineDefaults.k8sTestTokenCredentialId()) string(
						EnvironmentVariables.TOKEN_ENV_VAR,
						pipelineDefaults.k8sTestTokenCredentialId())
					// remove::end[K8S]
				}
			}
			scm {
				commonSteps.configureScm(delegate as ScmContext, fullGitRepo, "dev/${gitRepoName}/\${${EnvironmentVariables.PIPELINE_VERSION_ENV_VAR}}")
			}
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				commonSteps.runStep(delegate as StepContext, "test_rollback_smoke.sh")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
			}
		}
		customize(job)
		return new CreatedJob(job, autoNextJob(checker))
	}

	private boolean autoNextJob(StepEnabledChecker checker) {
		if (checker.stageStepSet()) {
			return checker.autoStageSet()
		}
		return checker.autoProdSet()
	}

	@Override void customize(FreeStyleJob job) {
		commonSteps.customizers().each {
			it.customizeAll(job)
			it.customizeTest(job)
		}
	}
}

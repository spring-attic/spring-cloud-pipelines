package org.springframework.cloud.pipelines.steps

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.helpers.ScmContext
import javaposse.jobdsl.dsl.helpers.publisher.PublisherContext
import javaposse.jobdsl.dsl.helpers.step.StepContext
import javaposse.jobdsl.dsl.helpers.wrapper.WrapperContext

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults

/**
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class TestOnStage {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	TestOnStage(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = new BashFunctions(pipelineDefaults.gitCredentials(),
			pipelineDefaults.gitEmail(), pipelineDefaults.gitUseSshKey())
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	void step(String projectName, Coordinates coordinates) {
		if (!pipelineDefaults.stageStep()) {
			return
		}
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		dsl.job("${projectName}-stage-env-test") {
			deliveryPipelineConfiguration('Stage', 'Tests on stage')
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
				credentialsBinding {
					// remove::start[CF]
					if (pipelineDefaults.cfTestCredentialId()) usernamePassword('PAAS_STAGE_USERNAME', 'PAAS_STAGE_PASSWORD', pipelineDefaults.cfTestCredentialId())
					// remove::end[CF]
					// remove::start[K8S]
					if (pipelineDefaults.k8sTestTokenCredentialId()) string("TOKEN", pipelineDefaults.k8sTestTokenCredentialId())
					// remove::end[K8S]
				}
				commonSteps.defaultWrappers(delegate as WrapperContext)
				if (pipelineDefaults.gitUseSshKey()) sshAgent(pipelineDefaults.gitSshCredentials())
			}
			scm {
				commonSteps.configureScm(delegate as ScmContext, fullGitRepo, "dev/${gitRepoName}/\${PIPELINE_VERSION}")
			}
			steps {
				commonSteps.downloadTools(delegate as StepContext, fullGitRepo)
				commonSteps.runStep(delegate as StepContext, "stage_e2e.sh")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
			}
		}
	}
}

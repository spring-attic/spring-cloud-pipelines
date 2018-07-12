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
class TestOnTest {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults
	private final BashFunctions bashFunctions
	private final CommonSteps commonSteps

	TestOnTest(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
		this.bashFunctions = new BashFunctions(pipelineDefaults.gitCredentials(),
			pipelineDefaults.gitEmail(), pipelineDefaults.gitUseSshKey())
		this.commonSteps = new CommonSteps(this.pipelineDefaults, this.bashFunctions)
	}

	void step(String projectName, Coordinates coordinates) {
		String gitRepoName = coordinates.gitRepoName
		String fullGitRepo = coordinates.fullGitRepo
		dsl.job("${projectName}-test-env-test") {
			deliveryPipelineConfiguration('Test', 'Tests on test')
			environmentVariables(pipelineDefaults.defaultEnvVars as Map<Object, Object>)
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				credentialsBinding {
					// remove::start[CF]
					if (pipelineDefaults.cfTestCredentialId()) usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', pipelineDefaults.cfTestCredentialId())
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
				commonSteps.runStep(delegate as StepContext, "test_smoke.sh")
			}
			publishers {
				commonSteps.defaultPublishers(delegate as PublisherContext)
			}
		}
	}
}

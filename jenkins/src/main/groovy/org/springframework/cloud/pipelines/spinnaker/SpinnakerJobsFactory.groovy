package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.jobs.FreeStyleJob

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.PipelineJobsFactory
import org.springframework.cloud.pipelines.spinnaker.pipeline.SpinnakerPipelineBuilder
import org.springframework.cloud.pipelines.spinnaker.pipeline.steps.ProdRemoveTag
import org.springframework.cloud.pipelines.spinnaker.pipeline.steps.ProdSetTag
import org.springframework.cloud.pipelines.spinnaker.pipeline.steps.StagePrepare
import org.springframework.cloud.pipelines.spinnaker.pipeline.steps.TestPrepare
import org.springframework.cloud.pipelines.steps.Build
import org.springframework.cloud.pipelines.steps.CommonSteps
import org.springframework.cloud.pipelines.steps.TestRollbackTest
import org.springframework.cloud.pipelines.steps.StageTest
import org.springframework.cloud.pipelines.steps.TestTest
import org.springframework.cloud.projectcrawler.Repository

/**
 * Factory for Spinnaker Jenkins jobs
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class SpinnakerJobsFactory implements PipelineJobsFactory {
	private final PipelineDefaults pipelineDefaults
	private final DslFactory dsl
	private final PipelineDescriptor descriptor
	private final Repository repository
	private final CommonSteps commonSteps

	SpinnakerJobsFactory(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor,
						 DslFactory dsl, Repository repository) {
		this.pipelineDefaults = pipelineDefaults
		this.dsl = dsl
		this.descriptor = descriptor
		this.repository = repository
		this.commonSteps = new CommonSteps(pipelineDefaults, new BashFunctions(pipelineDefaults))
	}

	@Override
	void allJobs(Coordinates coordinates, String pipelineVersion, Map<String, String> additionalFiles) {
		String gitRepoName = coordinates.gitRepoName
		String projectName = SpinnakerDefaults.projectName(gitRepoName)
		pipelineDefaults.addEnvVar("PROJECT_NAME", gitRepoName)
		println "Creating jobs and views for [${projectName}]"
		String script = commonSteps.readScript("download_latest_prod_binary.sh")
		new Build(dsl, pipelineDefaults, pipelineVersion) {
			@Override
			void customize(FreeStyleJob job) {
				job.steps {
					shell(script)
				}
				super.customize(job)
			}
		}.step(projectName, coordinates, descriptor)
		new TestPrepare(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new TestTest(dsl, pipelineDefaults) {
			@Override
			void customize(FreeStyleJob job) {
				setTestEnvVars(job, gitRepoName)
				super.customize(job)
			}
		}.step(projectName, coordinates, descriptor)
		new TestRollbackTest(dsl, pipelineDefaults) {
			@Override
			void customize(FreeStyleJob job) {
				setTestRollbackEnvVars(job, gitRepoName)
				super.customize(job)
			}
		}.step(projectName, coordinates, descriptor)
		new StagePrepare(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new StageTest(dsl, pipelineDefaults) {
			@Override
			void customize(FreeStyleJob job) {
				setStageEnvVars(job, gitRepoName)
				super.customize(job)
			}
		}.step(projectName, coordinates, descriptor)
		new ProdRemoveTag(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new ProdSetTag(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		println "Dumping the json with pipeline"
		dumpJsonToFile(descriptor, repository, additionalFiles)
	}

	protected void setTestEnvVars(FreeStyleJob job, String projectName) {
		job.wrappers {
			environmentVariables {
				env(EnvironmentVariables.APPLICATION_URL_ENV_VAR, "${pipelineDefaults.cfTestSpacePrefix()}-${projectName}.${pipelineDefaults.spinnakerTestHostname()}")
				env(EnvironmentVariables.STUBRUNNER_URL_ENV_VAR, "stubrunner-test-${projectName}.${pipelineDefaults.spinnakerTestHostname()}")
				env(EnvironmentVariables.CF_SKIP_PREPARE_FOR_TESTS_ENV_VAR, "true")
			}
		}
		job.parameters {
			stringParam(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR, "", "Version of the project to run the tests against")
		}
	}

	protected void setTestRollbackEnvVars(FreeStyleJob job, String projectName) {
		setTestEnvVars(job, projectName)
		job.parameters {
			stringParam(EnvironmentVariables.LATEST_PROD_VERSION_ENV_VAR, "", "Version of the project to run the tests against")
		}
	}

	protected void setStageEnvVars(FreeStyleJob job, String projectName) {
		job.wrappers {
			environmentVariables {
				env(EnvironmentVariables.APPLICATION_URL_ENV_VAR, "${projectName}-${pipelineDefaults.cfStageSpace()}.${pipelineDefaults.spinnakerStageHostname()}")
				env(EnvironmentVariables.CF_SKIP_PREPARE_FOR_TESTS_ENV_VAR, "true")
			}
		}
		job.parameters {
			stringParam(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR, "", "Version of the project to run the tests against")
		}
	}

	void dumpJsonToFile(PipelineDescriptor pipeline, Repository repo, Map<String, String> additionalFiles) {
		String json = new SpinnakerPipelineBuilder(pipeline, repo, pipelineDefaults, additionalFiles)
						.spinnakerPipeline()
		File pipelineJson = new File("${pipelineDefaults.workspace()}/build", repo.name + "_pipeline.json")
		pipelineJson.createNewFile()
		pipelineJson.text = json
	}
}

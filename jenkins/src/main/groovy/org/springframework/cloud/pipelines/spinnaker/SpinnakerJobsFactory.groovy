package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.PipelineJobsFactory
import org.springframework.cloud.pipelines.spinnaker.pipeline.SpinnakerPipelineBuilder
import org.springframework.cloud.pipelines.steps.Build
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

	SpinnakerJobsFactory(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor,
						 DslFactory dsl, Repository repository) {
		this.pipelineDefaults = pipelineDefaults
		this.dsl = dsl
		this.descriptor = descriptor
		this.repository = repository
	}

	@Override
	void allJobs(Coordinates coordinates, String pipelineVersion) {
		String gitRepoName = coordinates.gitRepoName
		String projectName = SpinnakerDefaults.projectName(gitRepoName)
		pipelineDefaults.addEnvVar("PROJECT_NAME", gitRepoName)
		println "Creating jobs and views for [${projectName}]"
		new Build(dsl, pipelineDefaults, pipelineVersion).step(projectName, coordinates, descriptor)
		new TestTest(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new TestRollbackTest(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new StageTest(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		println "Dumping the json with pipeline"
		dumpJsonToFile(descriptor, repository)
	}

	void dumpJsonToFile(PipelineDescriptor pipeline, Repository repo) {
		String json = new SpinnakerPipelineBuilder(pipeline, repo, pipelineDefaults)
						.spinnakerPipeline()
		File pipelineJson = new File("${pipelineDefaults.workspace()}/build", repo.name + "_pipeline.json")
		pipelineJson.createNewFile()
		pipelineJson.text = json
	}
}

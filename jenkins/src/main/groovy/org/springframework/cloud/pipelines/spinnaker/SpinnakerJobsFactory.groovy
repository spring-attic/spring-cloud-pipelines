package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.steps.Build
import org.springframework.cloud.pipelines.steps.RollbackTestOnTest
import org.springframework.cloud.pipelines.steps.TestOnStage
import org.springframework.cloud.pipelines.steps.TestOnTest

/**
 * Factory for Spinnaker Jenkins jobs
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class SpinnakerJobsFactory {
	private final PipelineDefaults pipelineDefaults
	private final DslFactory dsl
	private final PipelineDescriptor descriptor

	SpinnakerJobsFactory(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor, DslFactory dsl) {
		this.pipelineDefaults = pipelineDefaults
		this.dsl = dsl
		this.descriptor = descriptor
	}

	void allJobs(Coordinates coordinates, String pipelineVersion) {
		String gitRepoName = coordinates.gitRepoName
		String projectName = SpinnakerDefaults.projectName(gitRepoName)
		pipelineDefaults.addEnvVar("PROJECT_NAME", gitRepoName)
		println "Creating jobs and views for [${projectName}]"
		new Build(dsl, pipelineDefaults).step(projectName, pipelineVersion, coordinates, descriptor)
		new TestOnTest(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new RollbackTestOnTest(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
		new TestOnStage(dsl, pipelineDefaults).step(projectName, coordinates, descriptor)
	}

}

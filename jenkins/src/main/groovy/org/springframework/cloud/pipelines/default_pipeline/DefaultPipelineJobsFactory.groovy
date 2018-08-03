package org.springframework.cloud.pipelines.default_pipeline

import groovy.transform.CompileDynamic
import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.PipelineJobsFactory
import org.springframework.cloud.pipelines.steps.Build
import org.springframework.cloud.pipelines.steps.CreatedJob
import org.springframework.cloud.pipelines.steps.ProdComplete
import org.springframework.cloud.pipelines.steps.ProdDeploy
import org.springframework.cloud.pipelines.steps.ProdRollback
import org.springframework.cloud.pipelines.steps.StageDeploy
import org.springframework.cloud.pipelines.steps.StageTest
import org.springframework.cloud.pipelines.steps.Step
import org.springframework.cloud.pipelines.steps.TestDeploy
import org.springframework.cloud.pipelines.steps.TestDeployLatestProdVersion
import org.springframework.cloud.pipelines.steps.TestRollbackTest
import org.springframework.cloud.pipelines.steps.TestTest

/**
 * Factory for default Spring Cloud Pipelines Jenkins jobs. This class
 * knows how to create a pipeline and link the jobs in it.
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class DefaultPipelineJobsFactory implements PipelineJobsFactory {
	private final PipelineDefaults pipelineDefaults
	private final DslFactory dsl
	private final PipelineDescriptor descriptor

	DefaultPipelineJobsFactory(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor, DslFactory dsl) {
		this.pipelineDefaults = pipelineDefaults
		this.dsl = dsl
		this.descriptor = descriptor
	}

	@Override
	void allJobs(Coordinates coordinates, String pipelineVersion, Map<String, String> additionalFiles) {
		String gitRepoName = coordinates.gitRepoName
		String projectName = DefaultPipelineDefaults.projectName(gitRepoName)
		pipelineDefaults.addEnvVar("PROJECT_NAME", gitRepoName)
		println "Creating jobs and views for [${projectName}]"
		Node prodDeploy = new PipelineBuilder(pipelineDefaults, descriptor)
			.first(step(new Build(dsl, pipelineDefaults, pipelineVersion), projectName, coordinates))
			.then(step(new TestDeploy(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new TestTest(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new TestDeployLatestProdVersion(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new TestRollbackTest(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new StageDeploy(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new StageTest(dsl, pipelineDefaults), projectName, coordinates))
			.then(step(new ProdDeploy(dsl, pipelineDefaults), projectName, coordinates))
		prodDeploy.thenManualMultiple(
			step(new ProdComplete(dsl, pipelineDefaults), projectName, coordinates),
			step(new ProdRollback(dsl, pipelineDefaults), projectName, coordinates)
		)
	}

	private CreatedJob step(Step step, String projectName, Coordinates coordinates) {
		return step.step(projectName, coordinates, descriptor)
	}
}

@CompileStatic
class PipelineBuilder {
	private final PipelineDefaults pipelineDefaults
	private final PipelineDescriptor descriptor

	PipelineBuilder(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor) {
		this.pipelineDefaults = pipelineDefaults
		this.descriptor = descriptor
	}

	Node first(CreatedJob createdJob) {
		return new Node(pipelineDefaults, descriptor, createdJob)
	}
}

@CompileStatic
class Node {
	private final PipelineDefaults pipelineDefaults
	private final PipelineDescriptor descriptor
	private final CreatedJob createdJob

	Node(PipelineDefaults pipelineDefaults, PipelineDescriptor descriptor, CreatedJob createdJob) {
		this.pipelineDefaults = pipelineDefaults
		this.descriptor = descriptor
		this.createdJob = createdJob
	}

	Node then(CreatedJob nextJob) {
		if (nextJob == null) {
			return this
		}
		Node thatNode = new Node(pipelineDefaults, descriptor, nextJob)
		link(this, thatNode, this.createdJob.autoNextJob)
		return thatNode
	}

	@CompileDynamic
	// [Static type checking] - Cannot find matching method javaposse.jobdsl.dsl.Job#publishers(groovy.lang.Closure).
	// Please check if the declared type is right and if the method exists.
	void thenManualMultiple(CreatedJob... nextJobs) {
		String jobNames = nextJobs.collect { CreatedJob job -> job.job.name }.join(",")
		createdJob.job.publishers {
			buildPipelineTrigger(jobNames) {
				parameters {
					currentBuild()
				}
			}
		}
	}

	@CompileDynamic
	private void link(Node thisNode, Node thatNode, boolean auto) {
		String nextJob = thatNode.createdJob.job.name
		thisNode.createdJob.job.publishers {
			if (auto) {
				downstreamParameterized {
					trigger(nextJob) {
						parameters {
							currentBuild()
						}
					}
				}
			} else {
				buildPipelineTrigger(nextJob) {
					parameters {
						currentBuild()
					}
				}
			}
		}
	}
}

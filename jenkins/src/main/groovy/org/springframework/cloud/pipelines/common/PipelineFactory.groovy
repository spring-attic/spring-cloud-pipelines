package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.repositorymanagement.Repository
import org.springframework.cloud.repositorymanagement.RepositoryManagers

/**
 * Entry point to creating pipeline / build jobs and providing input for
 * views
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class PipelineFactory {

	private final PipelineJobsFactoryProvider factory
	private final PipelineDefaults defaults
	private final RepositoryManagers repositoryManagers
	private final DslFactory dsl

	PipelineFactory(PipelineJobsFactoryProvider factory, PipelineDefaults defaults,
					RepositoryManagers repositoryManagers, DslFactory dsl) {
		this.factory = factory
		this.defaults = defaults
		this.repositoryManagers = repositoryManagers
		this.dsl = dsl
	}

	/**
	 * Provides feedback about the generated jobs and repositories
	 * to generate views
	 *
	 * @param repositories - from the crawled org
	 * @param org - org from which we crawled the repos
	 * @param pipelineVersion - current pipeline version
	 */
	GeneratedJobs generate(List<Repository> repositories, String org,
						   String pipelineVersion) {
		List<Repository> repositoriesForViews = []
		Map<String, Exception> errors = [:]
		// for every repo
		repositories.each { Repository repo ->
			// fetch the descriptor (or pick one for tests form env var)
			String descriptor = defaults.testModeDescriptor() != null ?
				defaults.testModeDescriptor() as String :
				repositoryManagers.fileContent(org,
					repo.name, repo.requestedBranch,
					defaults.pipelineDescriptor())
			// parse it
			PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
			PipelineDefaults pipelineDefaults = new PipelineDefaults(defaults.variables)
			pipelineDefaults.updateFromPipeline(pipeline)
			if (pipeline.hasMonoRepoProjects()) {
				// for monorepos treat the single repo as multiple ones
				pipeline.pipeline.project_names.each { String monoRepo ->
					Repository monoRepository = new Repository(monoRepo, repo.ssh_url, repo.clone_url, repo.requestedBranch)
					repositoriesForViews.add(monoRepository)
					errors.putAll(allJobs(pipeline, monoRepository, pipelineVersion))
				}
			} else {
				// for any other repo build a single pipeline
				repositoriesForViews.add(repo)
				errors.putAll(allJobs(pipeline, repo, pipelineVersion))
			}
		}
		return new GeneratedJobs(repositoriesForViews, errors)
	}

	private Map<String, Exception> allJobs(PipelineDescriptor pipeline,
										   Repository repo, String pipelineVersion) {
		try {
			factory.get(defaults, dsl, pipeline, repo).allJobs(Coordinates.fromRepo(repo, defaults), pipelineVersion)
			return [:]
		} catch (Exception t) {
			return [(repo.name): t]
		}
	}
}

interface PipelineJobsFactoryProvider {
	PipelineJobsFactory get(PipelineDefaults pipelineDefaults,
							DslFactory dsl,
							PipelineDescriptor descriptor,
							Repository repository)
}

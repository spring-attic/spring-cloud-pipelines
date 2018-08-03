package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.projectcrawler.Repository
import org.springframework.cloud.projectcrawler.ProjectCrawler

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
	private final ProjectCrawler projectCrawler
	private final DslFactory dsl

	PipelineFactory(PipelineJobsFactoryProvider factory, PipelineDefaults defaults,
					ProjectCrawler projectCrawler, DslFactory dsl) {
		this.factory = factory
		this.defaults = defaults
		this.projectCrawler = projectCrawler
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
			try {
				// fetch the descriptor (or pick one for tests form env var)
				String descriptor = pipelineDescriptor(org, repo)
				// fetch additional files
				Map<String, String> additionalFiles = additionalFiles(repo, org)
				// parse it
				PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
				PipelineDefaults pipelineDefaults = new PipelineDefaults(defaults.variables)
				pipelineDefaults.updateFromPipeline(pipeline)
				if (pipeline.hasMonoRepoProjects()) {
					// for monorepos treat the single repo as multiple ones
					pipeline.pipeline.project_names.each { String monoRepo ->
						Repository monoRepository = new Repository(monoRepo, repo.ssh_url, repo.clone_url, repo.requestedBranch)
						repositoriesForViews.add(monoRepository)
						allJobs(pipeline, monoRepository, pipelineVersion, additionalFiles)
					}
				} else {
					// for any other repo build a single pipeline
					repositoriesForViews.add(repo)
					allJobs(pipeline, repo, pipelineVersion, additionalFiles)
				}
			} catch (Exception e) {
				errors.put(repo.name, e)
				return
			}
		}
		return new GeneratedJobs(repositoriesForViews, errors)
	}

	protected String pipelineDescriptor(String org, Repository repo) {
		String descriptor = defaults.testModeDescriptor() != null ?
			defaults.testModeDescriptor() as String :
			projectCrawler.fileContent(org,
				repo.name, repo.requestedBranch,
				defaults.pipelineDescriptor())
		return descriptor
	}

	protected Map<String, String> additionalFiles(Repository repo, String org) {
		Map<String, String> additionalFiles =
			defaults.testModeDescriptor() != null ? [
				"manifest.yml": """
applications:
- name: github-webhook
  services:
    - github-rabbitmq
    - github-eureka
  disk_quota: 2000M
  memory: 3000M
  env:
    SPRING_PROFILES_ACTIVE: cloud
    DEBUG: "true"
"""
			]  : factory.additionalFiles().collectEntries {
				String fileContent = projectCrawler.fileContent(org, repo.name,
					repo.requestedBranch, it)
				if (fileContent) return [(it): fileContent]
				return [:]
			} as Map<String, String>
		return additionalFiles
	}

	private void allJobs(PipelineDescriptor pipeline,
										   Repository repo, String pipelineVersion,
										   Map<String, String> additionalFiles) {
		factory.get(defaults, dsl, pipeline, repo).allJobs(Coordinates.fromRepo(repo, defaults),
			pipelineVersion, additionalFiles)
	}
}


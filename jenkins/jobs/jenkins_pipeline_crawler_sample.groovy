import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.default_pipeline.DefaultPipelineJobsFactory
import org.springframework.cloud.pipelines.default_pipeline.DefaultView
import org.springframework.cloud.repositorymanagement.OptionsBuilder
import org.springframework.cloud.repositorymanagement.Repository
import org.springframework.cloud.repositorymanagement.RepositoryManagers

DslFactory dsl = this

// These will be taken either from seed or global variables
PipelineDefaults defaults = new PipelineDefaults(binding.variables)
String pipelineVersion = defaults.pipelineVersion()
String org = binding.variables["ORG"] ?: "sc-pipelines"
String repoType = binding.variables["REPO_MANAGEMENT_TYPE"] ?: "GITHUB"
String urlRoot = binding.variables["REPO_URL_ROOT"] ?: "https://github.com"

// crawl the org
RepositoryManagers repositoryManagers = new RepositoryManagers(OptionsBuilder
	.builder().rootUrl(urlRoot)
	.username(defaults.gitUsername())
	.password(defaults.gitPassword())
	.token(defaults.gitToken())
	.repository(repoType).build())
// get the repos from the org
List<Repository> repositories = binding.variables["TEST_MODE_DESCRIPTOR"] != null ?
	[new Repository("foo", "git@bar.com:baz/foo.git", "http://bar.com/baz/foo.git", "master")]
	: repositoryManagers.repositories(org)
List<Repository> repositoriesForViews = []
// for every repo
repositories.each { Repository repo ->
	// fetch the descriptor (or pick one for tests form env var)
	String descriptor = binding.variables["TEST_MODE_DESCRIPTOR"] != null ?
		binding.variables["TEST_MODE_DESCRIPTOR"] as String :
		repositoryManagers.fileContent(org, repo.name, repo.requestedBranch,
			defaults.pipelineDescriptor())
	// parse it
	PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
	PipelineDefaults pipelineDefaults = new PipelineDefaults(binding.variables)
	pipelineDefaults.updateFromPipeline(pipeline)
	if (pipeline.hasMonoRepoProjects()) {
		// for monorepos treat the single repo as multiple ones
		pipeline.pipeline.project_names.each { String monoRepo ->
			Repository monoRepository = new Repository(monoRepo, repo.ssh_url, repo.clone_url, repo.requestedBranch)
			Coordinates coordinates = Coordinates.fromRepo(monoRepository, defaults)
			repositoriesForViews.add(monoRepository)
			new DefaultPipelineJobsFactory(pipeline, pipelineDefaults, dsl)
				.allJobs(coordinates, pipelineVersion)
		}
	} else {
		// for any other repo build a single pipeline
		Coordinates coordinates = Coordinates.fromRepo(repo, defaults)
		repositoriesForViews.add(repo)
		new DefaultPipelineJobsFactory(pipeline, pipelineDefaults, dsl)
			.allJobs(coordinates, pipelineVersion)
	}
}

new DefaultView(defaults, dsl).allViews(repositories)

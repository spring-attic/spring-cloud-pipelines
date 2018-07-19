import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
import org.springframework.cloud.pipelines.spinnaker.SpinnakerJobsFactory
import org.springframework.cloud.pipelines.spinnaker.pipeline.SpinnakerPipelineBuilder
import org.springframework.cloud.pipelines.steps.Build
import org.springframework.cloud.pipelines.steps.RollbackTestOnTest
import org.springframework.cloud.pipelines.steps.TestOnStage
import org.springframework.cloud.pipelines.steps.TestOnTest
import org.springframework.cloud.pipelines.views.DefaultView
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
String workspace = binding.variables["WORKSPACE"] ?: "."

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
// JSON dump
Closure dumpJsonToFile = { PipelineDescriptor pipeline, Repository repo ->
	String json = new SpinnakerPipelineBuilder(pipeline, repo, defaults)
		.spinnakerPipeline()
	File pipelineJson = new File("${workspace}/build", repo.name + "_pipeline.json")
	pipelineJson.createNewFile()
	pipelineJson.text = json
}
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
			repositoriesForViews.add(monoRepository)
			new SpinnakerJobsFactory(pipelineDefaults, pipeline, dsl)
				.allJobs(Coordinates.fromRepo(monoRepository, defaults), pipelineVersion)
			dumpJsonToFile(pipeline, monoRepository)
		}
	} else {
		// for any other repo build a single pipeline
		repositoriesForViews.add(repo)
		new SpinnakerJobsFactory(pipelineDefaults, pipeline, dsl)
			.allJobs(Coordinates.fromRepo(repo, defaults), pipelineVersion)
		dumpJsonToFile(pipeline, repo)
	}
}
// build the views
new DefaultView(dsl, defaults).view(repositoriesForViews)

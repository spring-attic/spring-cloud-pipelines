import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.helpers.ScmContext

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
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

// crawl the org
RepositoryManagers repositoryManagers = new RepositoryManagers(OptionsBuilder
	.builder().rootUrl(urlRoot)
	.username(defaults.gitUsername()).password(defaults.gitPassword())
	.token(defaults.gitToken())
	.repository(repoType).build())
// get the repos from the org
List<Repository> repositories = binding.variables["TEST_MODE"] ? [] : repositoryManagers.repositories(org)
// definition of project building
Closure buildProjects = { Coordinates coordinates ->
	String gitRepoName = coordinates.gitRepoName
	String projectName = SpinnakerDefaults.projectName(gitRepoName)
	defaults.addEnvVar("PROJECT_NAME", gitRepoName)
	println "Creating jobs and views for [${projectName}]"
	new Build(dsl, defaults).step(projectName, pipelineVersion, coordinates)
	new TestOnTest(dsl, defaults).step(projectName, coordinates)
	new RollbackTestOnTest(dsl, defaults).step(projectName, coordinates)
	new TestOnStage(dsl, defaults).step(projectName, coordinates)
}
List<Repository> repositoriesForViews = []
// for every repo
repositories.each { Repository repo ->
	// fetch the descriptor
	String descriptor = repositoryManagers.fileContent(org, repo.name,
		repo.requestedBranch, defaults.pipelineDescriptor())
	// parse it
	PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
	defaults.updateFromPipeline(pipeline)
	if (pipeline.hasMonoRepoProjects()) {
		// for monorepos treat the single repo as multiple ones
		pipeline.pipeline.project_names.each { String monoRepo ->
			Repository monoRepository = new Repository(monoRepo, repo.ssh_url, repo.clone_url, repo.requestedBranch)
			repositoriesForViews.add(monoRepository)
			buildProjects(Coordinates.fromRepo(monoRepository, defaults))
		}
	} else {
		// for any other repo build a single pipeline
		repositoriesForViews.add(repo)
		buildProjects(Coordinates.fromRepo(repo, defaults))
	}
}

// build the views
new DefaultView(dsl, defaults).view(repositoriesForViews)

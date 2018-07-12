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

// go the old way if set
String reposFromBinding = binding.variables["REPOS"] ?: ""
String org = binding.variables["ORGANIZATION"] ?: "sc-pipelines"
String repoType = binding.variables["REPO_MANAGEMENT_TYPE"] ?: "GITHUB"
String urlRoot = binding.variables["REPO_URL_ROOT"] ?: "https://github.com"

RepositoryManagers repositoryManagers = new RepositoryManagers(OptionsBuilder
	.builder().rootUrl(urlRoot).repository(repoType).build())
List<Repository> repositories = binding.variables["TEST_MODE"] ? [] : repositoryManagers.repositories(org)
repositories.each {
	String descriptor = repositoryManagers.fileContent(org, it.name,
		it.requestedBranch, defaults.pipelineDescriptor())
	PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
	defaults.updateFromPipeline(pipeline)
	Coordinates coordinates = Coordinates.fromRepo(it, defaults)
	String gitRepoName = coordinates.gitRepoName
	String projectName = SpinnakerDefaults.projectName(gitRepoName)
	defaults.addEnvVar("PROJECT_NAME", gitRepoName)
	println "Creating jobs and views for [${projectName}]"
	new Build(dsl, defaults).step(projectName, pipelineVersion, coordinates)
	new TestOnTest(dsl, defaults).step(projectName, coordinates)
	new RollbackTestOnTest(dsl, defaults).step(projectName, coordinates)
	new TestOnStage(dsl, defaults).step(projectName, coordinates)
}

new DefaultView(dsl, defaults).view(repositories)

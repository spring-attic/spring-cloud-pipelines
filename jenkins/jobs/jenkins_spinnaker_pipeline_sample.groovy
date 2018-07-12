import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.helpers.ScmContext

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.steps.Build
import org.springframework.cloud.pipelines.steps.RollbackTestOnTest
import org.springframework.cloud.pipelines.steps.TestOnStage
import org.springframework.cloud.pipelines.steps.TestOnTest
import org.springframework.cloud.repositorymanagement.OptionsBuilder
import org.springframework.cloud.repositorymanagement.Repositories
import org.springframework.cloud.repositorymanagement.Repository
import org.springframework.cloud.repositorymanagement.RepositoryManagers

DslFactory dsl = this

// These will be taken either from seed or global variables
PipelineDefaults defaults = new PipelineDefaults(binding.variables)
String pipelineVersion = defaults.pipelineVersion()

// go the old way if set
String reposFromBinding = binding.variables["REPOS"] ?: ""
String org = binding.variables["ORGANIZATION"] ?: "marcingrzejszczak"
String repoType = binding.variables["REPO_MANAGEMENT_TYPE"] ?: "GITHUB"

RepositoryManagers repositoryManagers = new RepositoryManagers(OptionsBuilder
	.builder()
	.repository(repoType)
// TODO: allow creating repos for the whole org
	.exclude(".*")
		.project("github-analytics")
		.project("github-webhook")
	.build())
List<Repository> repositories = binding.variables["TEST_MODE"] ? [] : repositoryManagers.repositories(org)
repositories.each {
	String descriptor = repositoryManagers.fileContent(org, it.name,
		it.requestedBranch, defaults.pipelineDescriptor())
	PipelineDescriptor pipeline = PipelineDescriptor.from(descriptor)
	defaults.updateFromPipeline(pipeline)
	Coordinates coordinates = Coordinates.fromRepo(
		defaults.gitUseSshKey() ? it.ssh_url : it.clone_url)
	String gitRepoName = coordinates.gitRepoName
	String projectName = "spinnaker-${gitRepoName}-pipeline"
	defaults.addEnvVar("PROJECT_NAME", gitRepoName)

	//  ======= JOBS =======
	new Build(dsl, defaults).step(projectName, pipelineVersion, coordinates)
	new TestOnTest(dsl, defaults).step(projectName, coordinates)
	new RollbackTestOnTest(dsl, defaults).step(projectName, coordinates)
	new TestOnStage(dsl, defaults).step(projectName, coordinates)
}

List<String> parsedRepos = reposFromBinding.split(",")
parsedRepos.each {

}

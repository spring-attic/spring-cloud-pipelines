import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.GeneratedJobs
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.PipelineFactory
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaultView
import org.springframework.cloud.pipelines.spinnaker.SpinnakerJobsFactory
import org.springframework.cloud.pipelines.test.TestUtils
import org.springframework.cloud.projectcrawler.OptionsBuilder
import org.springframework.cloud.projectcrawler.Repository
import org.springframework.cloud.projectcrawler.ProjectCrawler

DslFactory dsl = this

// These will be taken either from seed or global variables
PipelineDefaults defaults = new PipelineDefaults(binding.variables)
String pipelineVersion = defaults.pipelineVersion()
String org = defaults.repoOrganization() ?: "sc-pipelines"
String repoType = defaults.repoManagement() ?: "GITHUB"
String urlRoot = defaults.repoUrlRoot() ?: "https://github.com"

// crawl the org
ProjectCrawler crawler = new ProjectCrawler(OptionsBuilder
	.builder().rootUrl(urlRoot)
	.username(defaults.gitUsername())
	.password(defaults.gitPassword())
	.token(defaults.gitToken())
	.exclude(defaults.repoProjectsExcludePattern())
	.repository(repoType).build())

// get the repos from the org
List<Repository> repositories = defaults.testModeDescriptor() != null ?
	TestUtils.TEST_REPO : crawler.repositories(org)

// generate jobs and store errors
GeneratedJobs generatedJobs = new PipelineFactory({ PipelineDefaults pipelineDefaults,
													DslFactory dslFactory, PipelineDescriptor descriptor,
													Repository repository ->
	return new SpinnakerJobsFactory(pipelineDefaults, descriptor, dslFactory, repository)
}, defaults, crawler, dsl).generate(repositories, org, pipelineVersion)

if (generatedJobs.hasErrors()) {
	println "\n\n\nWARNING, THERE WERE ERRORS WHILE TRYING TO BUILD PROJECTS\n\n\n"
	println generatedJobs.errors
}

// build the views
new SpinnakerDefaultView(dsl, defaults).view(generatedJobs.repositoriesForViews)

import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

// we're parsing the REPOS parameter to retrieve list of repos to build
String repos = binding.variables['REPOS'] ?:
		['https://github.com/marcingrzejszczak/github-analytics',
		 'https://github.com/marcingrzejszczak/github-webhook'].join(',')
List<String> parsedRepos = repos.split(',')
parsedRepos.each {
	List<String> parsedEntry = it.split('\\$')
	String gitRepoName
	String fullGitRepo
	if (parsedEntry.size() > 1) {
		gitRepoName = parsedEntry[0]
		fullGitRepo = parsedEntry[1]
	} else {
		gitRepoName = parsedEntry[0].split('/').last()
		fullGitRepo = parsedEntry[0]
	}
	String projectName = "${gitRepoName}-pipeline"
	dsl.deliveryPipelineView(projectName) {
		allowPipelineStart()
		pipelineInstances(5)
		showAggregatedPipeline(false)
		columns(1)
		updateInterval(5)
		enableManualTriggers()
		showAvatars()
		showChangeLog()
		pipelines {
			component("Deployment", "${projectName}-build")
		}
		allowRebuild()
		showDescription()
		showPromotions()
		showTotalBuildTime()
		configure {
			(it / 'showTestResults').setValue(true)
			(it / 'pagingEnabled').setValue(true)
		}
	}
}

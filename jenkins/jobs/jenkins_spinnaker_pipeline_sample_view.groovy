import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

// we're parsing the REPOS parameter to retrieve list of repos to build
String repos = binding.variables['REPOS'] ?:
		['https://github.com/marcingrzejszczak/github-analytics',
		 'https://github.com/marcingrzejszczak/github-webhook'].join(',')
List<String> parsedRepos = repos.split(',')
parsedRepos.each {
	String gitRepoName = it.split('/').last() - '.git'
	int customNameIndex = it.indexOf('$')
	int customBranchIndex = it.indexOf('#')
	if (customNameIndex > -1 && (customNameIndex < customBranchIndex || customBranchIndex == -1)) {
		if (customNameIndex < customBranchIndex) {
			// url$newName#someBranch
			gitRepoName = it.substring(customNameIndex + 1, customBranchIndex)
		} else if (customBranchIndex == -1) {
			// url$newName
			gitRepoName = it.substring(customNameIndex + 1)
		}
	} else if (customBranchIndex > -1) {
		if (customBranchIndex < customNameIndex) {
			// url#someBranch$newName
			gitRepoName = it.substring(customNameIndex + 1)
		} else if (customNameIndex == -1) {
			// url#someBranch
			gitRepoName = it.substring(it.lastIndexOf("/") + 1, customBranchIndex)
		}
	}
	dsl.listView("spinnnaker-${gitRepoName}") {
		jobs {
			regex("spinnaker-${gitRepoName}.*")
		}
		columns {
			status()
			name()
			lastSuccess()
			lastFailure()
			lastBuildConsole()
			buildButton()
		}
	}
}

dsl.listView("ci") {
	jobs {
		regex(".*-ci")
	}
	columns {
		status()
		name()
		lastSuccess()
		lastFailure()
		lastBuildConsole()
		buildButton()
	}
}

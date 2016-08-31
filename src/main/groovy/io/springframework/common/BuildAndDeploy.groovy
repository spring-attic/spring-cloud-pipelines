package io.springframework.common

/**
 * @author Marcin Grzejszczak
 */
trait BuildAndDeploy {

	String prefixJob(String projectName) {
		if (projectName == projectSuffix()){
			return projectName
		}
		return projectName.startsWith(projectSuffix()) ? projectName : "${projectSuffix()}-${projectName}"
	}

	abstract String projectSuffix()

	String cleanAndDeploy() {
		return '''./mvnw clean deploy -nsu -P docs,integration -U $MVN_LOCAL_OPTS -Dmaven.test.redirectTestOutputToFile=true -Dsurefire.runOrder=random'''
	}

	String deployDocs() {
		return '''echo "Deploying docs" && ./docs/src/main/asciidoc/ghpages.sh'''
	}

	String branchVar() {
		return 'BRANCH'
	}

	String masterBranch() {
		return 'master'
	}
}
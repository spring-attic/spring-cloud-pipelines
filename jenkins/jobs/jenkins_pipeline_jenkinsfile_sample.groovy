import javaposse.jobdsl.dsl.DslFactory
import javaposse.jobdsl.dsl.helpers.BuildParametersContext

DslFactory dsl = this

// Git credentials to use
String gitCredentials = binding.variables["GIT_CREDENTIAL_ID"] ?: "git"
// we're parsing the REPOS parameter to retrieve list of repos to build
String repos = binding.variables["REPOS"] ?: [
		"https://github.com/spring-cloud/github-analytics",
		"https://github.com/spring-cloud/github-webhook"
	].join(",")
List<String> parsedRepos = repos.split(",")
String jenkinsfileDir = binding.variables["JENKINSFILE_DIR"] ?: "${WORKSPACE}/jenkins/declarative-pipeline"

Map<String, String> envs = [:]
envs['PIPELINE_VERSION_FORMAT'] = binding.variables["PIPELINE_VERSION"] ?: '''${BUILD_DATE_FORMATTED, \"yyMMdd_HHmmss\"}-VERSION'''
envs['PIPELINE_VERSION_PREFIX'] = binding.variables["PIPELINE_VERSION"] ?: '''1.0.0.M1'''
envs['CF_TEST_API_URL'] = binding.variables['CF_TEST_API_URL'] ?: 'api.local.pcfdev.io'
envs['CF_STAGE_API_URL'] = binding.variables['CF_STAGE_API_URL'] ?: 'api.local.pcfdev.io'
envs['CF_PROD_API_URL'] = binding.variables['CF_PROD_API_URL'] ?: 'api.local.pcfdev.io'
envs['CF_TEST_ORG'] = binding.variables['CF_TEST_ORG'] ?: 'pcfdev-org'
envs['CF_TEST_SPACE'] = binding.variables['CF_TEST_SPACE'] ?: 'pfcdev-test'
envs['CF_STAGE_ORG'] = binding.variables['CF_STAGE_ORG'] ?: 'pcfdev-org'
envs['CF_STAGE_SPACE'] = binding.variables['CF_STAGE_SPACE'] ?: 'pfcdev-stage'
envs['CF_PROD_ORG'] = binding.variables['CF_PROD_ORG'] ?: 'pcfdev-org'
envs['CF_PROD_SPACE'] = binding.variables['CF_PROD_SPACE'] ?: 'pfcdev-prod'
envs['CF_HOSTNAME_UUID'] = binding.variables['CF_HOSTNAME_UUID'] ?: ''
envs['M2_SETTINGS_REPO_ID'] = binding.variables['M2_SETTINGS_REPO_ID'] ?: 'artifactory-local'
envs['REPO_WITH_JARS'] = binding.variables['REPO_WITH_JARS'] ?: 'http://artifactory:8081/artifactory/libs-release-local'
envs['GIT_CREDENTIAL_ID'] = gitCredentials 
envs['JDK_VERSION'] = binding.variables["JDK_VERSION"] ?: "jdk8"
envs['GIT_EMAIL'] = binding.variables["GIT_EMAIL"] ?: "pivo@tal.com"
envs['GIT_NAME'] = binding.variables["GIT_NAME"] ?: "Pivo Tal"
envs['TOOLS_REPOSITORY'] = binding.variables["TOOLS_REPOSITORY"] ?: 'https://github.com/spring-cloud/spring-cloud-pipelines'
envs['TOOLS_BRANCH'] = binding.variables["TOOLS_BRANCH"] ?: '*/master'
envs['CF_TEST_CREDENTIAL_ID'] = binding.variables["CF_TEST_CREDENTIAL_ID"] ?: "cf-test"
envs['CF_STAGE_CREDENTIAL_ID'] = binding.variables["CF_STAGE_CREDENTIAL_ID"] ?: "cf-stage"
envs['CF_PROD_CREDENTIAL_ID'] = binding.variables["CF_PROD_CREDENTIAL_ID"] ?: "cf-prod"

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
	String projectName = "${gitRepoName}-declarative-pipeline"
	
	envs['GIT_REPOSIOTRY'] = fullGitRepo

	dsl.pipelineJob(projectName) {
		wrappers {
			environmentVariables {
				environmentVariables(envs)
			}
			parameters {
				booleanParam('REDOWNLOAD_INFRA', false, "If Eureka & StubRunner & CF binaries should be redownloaded if already present")
				booleanParam('REDEPLOY_INFRA', true, "If Eureka & StubRunner binaries should be redeployed if already present")
				stringParam('EUREKA_GROUP_ID', 'com.example.eureka', "Group Id for Eureka used by tests")
				stringParam('EUREKA_ARTIFACT_ID', 'github-eureka', "Artifact Id for Eureka used by tests")
				stringParam('EUREKA_VERSION', '0.0.1.M1', "Artifact Version for Eureka used by tests")
				stringParam('STUBRUNNER_GROUP_ID', 'com.example.github', "Group Id for Stub Runner used by tests")
				stringParam('STUBRUNNER_ARTIFACT_ID', 'github-analytics-stub-runner-boot', "Artifact Id for Stub Runner used by tests")
				stringParam('STUBRUNNER_VERSION', '0.0.1.M1', "Artifact Version for Stub Runner used by tests")
			}
		}
		definition {
			cps {
				script("""
					${dsl.readFileFromWorkspace(jenkinsfileDir + '/Jenkinsfile-sample')}
				""")
			}
		}
	}
}

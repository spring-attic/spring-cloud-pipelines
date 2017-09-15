import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

// Git credentials to use
String gitCredentials = binding.variables["GIT_CREDENTIAL_ID"] ?: "git"
// we're parsing the REPOS parameter to retrieve list of repos to build
String repos = binding.variables["REPOS"] ?: [
		"https://github.com/spring-cloud-samples/github-analytics",
		"https://github.com/spring-cloud-samples/github-webhook"
	].join(",")
List<String> parsedRepos = repos.split(",")
String jenkinsfileDir = binding.variables["JENKINSFILE_DIR"] ?: "${WORKSPACE}/jenkins/declarative-pipeline"

Map<String, Object> envs = [:]
envs['PIPELINE_VERSION_FORMAT'] = binding.variables["PIPELINE_VERSION"] ?: '''${BUILD_DATE_FORMATTED, \"yyMMdd_HHmmss\"}-VERSION'''
envs['PIPELINE_VERSION_PREFIX'] = binding.variables["PIPELINE_VERSION"] ?: '''1.0.0.M1'''
envs['REPO_WITH_BINARIES_CREDENTIALS_ID'] = binding.variables['REPO_WITH_BINARIES_CREDENTIALS_ID'] ?: 'repo-with-binaries'
envs['GIT_CREDENTIAL_ID'] = gitCredentials
envs['JDK_VERSION'] = binding.variables["JDK_VERSION"] ?: "jdk8"
envs['GIT_EMAIL'] = binding.variables["GIT_EMAIL"] ?: "pivo@tal.com"
envs['GIT_NAME'] = binding.variables["GIT_NAME"] ?: "Pivo Tal"
envs["PAAS_TYPE"] = binding.variables["PAAS_TYPE"] ?: "cf"
envs['TOOLS_REPOSITORY'] = binding.variables["TOOLS_REPOSITORY"] ?: 'https://github.com/spring-cloud/spring-cloud-pipelines'
envs["TOOLS_BRANCH"] = binding.variables["TOOLS_BRANCH"] ?: "master"
envs["M2_SETTINGS_REPO_ID"] = binding.variables["M2_SETTINGS_REPO_ID"] ?: "artifactory-local"
envs["REPO_WITH_BINARIES"] = binding.variables["REPO_WITH_BINARIES"] ?: "http://artifactory:8081/artifactory/libs-release-local"
// remove::start[CF]
envs["PAAS_TEST_API_URL"] = binding.variables["PAAS_TEST_API_URL"] ?: "api.local.pcfdev.io"
envs["PAAS_STAGE_API_URL"] = binding.variables["PAAS_STAGE_API_URL"] ?: "api.local.pcfdev.io"
envs["PAAS_PROD_API_URL"] = binding.variables["PAAS_PROD_API_URL"] ?: "api.local.pcfdev.io"
envs["PAAS_TEST_ORG"] = binding.variables["PAAS_TEST_ORG"] ?: "pcfdev-org"
envs["PAAS_TEST_SPACE"] = binding.variables["PAAS_TEST_SPACE"] ?: "pfcdev-test"
envs["PAAS_STAGE_ORG"] = binding.variables["PAAS_STAGE_ORG"] ?: "pcfdev-org"
envs["PAAS_STAGE_SPACE"] = binding.variables["PAAS_STAGE_SPACE"] ?: "pfcdev-stage"
envs["PAAS_PROD_ORG"] = binding.variables["PAAS_PROD_ORG"] ?: "pcfdev-org"
envs["PAAS_PROD_SPACE"] = binding.variables["PAAS_PROD_SPACE"] ?: "pfcdev-prod"
envs["PAAS_HOSTNAME_UUID"] = binding.variables["PAAS_HOSTNAME_UUID"] ?: ""
envs["APP_MEMORY_LIMIT"] = binding.variables["APP_MEMORY_LIMIT"] ?: ""
envs["JAVA_BUILDPACK_URL"] = binding.variables["JAVA_BUILDPACK_URL"] ?: "https://github.com/cloudfoundry/java-buildpack.git#v3.8.1"
// remove::end[CF]
// remove::start[K8S]
envs["DOCKER_REGISTRY_ORGANIZATION"] = binding.variables["DOCKER_REGISTRY_ORGANIZATION"] ?: "scpipelines"
envs["PAAS_TEST_API_URL"] = binding.variables["PAAS_TEST_API_URL"] ?: "192.168.99.100:8443"
envs["PAAS_STAGE_API_URL"] = binding.variables["PAAS_STAGE_API_URL"] ?: "192.168.99.100:8443"
envs["PAAS_PROD_API_URL"] = binding.variables["PAAS_PROD_API_URL"] ?: "192.168.99.100:8443"
envs["PAAS_TEST_CA"] = binding.variables["PAAS_TEST_CA"] ?: "/usr/share/jenkins/cert/ca.crt"
envs["PAAS_STAGE_CA"] = binding.variables["PAAS_STAGE_CA"] ?: "/usr/share/jenkins/cert/ca.crt"
envs["PAAS_PROD_CA"] = binding.variables["PAAS_PROD_CA"] ?: "/usr/share/jenkins/cert/ca.crt"
envs["PAAS_TEST_CLIENT_CERT"] = binding.variables["PAAS_TEST_CLIENT_CERT"] ?: "/usr/share/jenkins/cert/apiserver.crt"
envs["PAAS_STAGE_CLIENT_CERT"] = binding.variables["PAAS_STAGE_CLIENT_CERT"] ?: "/usr/share/jenkins/cert/apiserver.crt"
envs["PAAS_PROD_CLIENT_CERT"] = binding.variables["PAAS_PROD_CLIENT_CERT"] ?: "/usr/share/jenkins/cert/apiserver.crt"
envs["PAAS_TEST_CLIENT_KEY"] = binding.variables["PAAS_TEST_CLIENT_KEY"] ?: "/usr/share/jenkins/cert/apiserver.key"
envs["PAAS_STAGE_CLIENT_KEY"] = binding.variables["PAAS_STAGE_CLIENT_KEY"] ?: "/usr/share/jenkins/cert/apiserver.key"
envs["PAAS_PROD_CLIENT_KEY"] = binding.variables["PAAS_PROD_CLIENT_KEY"] ?: "/usr/share/jenkins/cert/apiserver.key"
envs["PAAS_TEST_CLUSTER_NAME"] = binding.variables["PAAS_TEST_CLUSTER_NAME"] ?: "minikube"
envs["PAAS_STAGE_CLUSTER_NAME"] = binding.variables["PAAS_STAGE_CLUSTER_NAME"] ?: "minikube"
envs["PAAS_PROD_CLUSTER_NAME"] = binding.variables["PAAS_PROD_CLUSTER_NAME"] ?: "minikube"
envs["PAAS_TEST_CLUSTER_USERNAME"] = binding.variables["PAAS_TEST_CLUSTER_USERNAME"] ?: "minikube"
envs["PAAS_STAGE_CLUSTER_USERNAME"] = binding.variables["PAAS_STAGE_CLUSTER_USERNAME"] ?: "minikube"
envs["PAAS_PROD_CLUSTER_USERNAME"] = binding.variables["PAAS_PROD_CLUSTER_USERNAME"] ?: "minikube"
envs["PAAS_TEST_SYSTEM_NAME"] = binding.variables["PAAS_TEST_SYSTEM_NAME"] ?: "minikube"
envs["PAAS_STAGE_SYSTEM_NAME"] = binding.variables["PAAS_STAGE_SYSTEM_NAME"] ?: "minikube"
envs["PAAS_PROD_SYSTEM_NAME"] = binding.variables["PAAS_PROD_SYSTEM_NAME"] ?: "minikube"
envs["PAAS_TEST_NAMESPACE"] = binding.variables["PAAS_TEST_NAMESPACE"] ?: "sc-pipelines-test"
envs["PAAS_STAGE_NAMESPACE"] = binding.variables["PAAS_STAGE_NAMESPACE"] ?: "sc-pipelines-stage"
envs["PAAS_PROD_NAMESPACE"] = binding.variables["PAAS_PROD_NAMESPACE"] ?: "sc-pipelines-prod"
envs["KUBERNETES_MINIKUBE"] = binding.variables["KUBERNETES_MINIKUBE"] ?: "true"

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
	
	envs['GIT_REPOSITORY'] = fullGitRepo

	dsl.pipelineJob(projectName) {
		wrappers {
			environmentVariables {
				environmentVariables(envs)
			}
		}
		definition {
			cps {
				script("""${dsl.readFileFromWorkspace(jenkinsfileDir + '/Jenkinsfile-sample')}""")
			}
		}
	}
}

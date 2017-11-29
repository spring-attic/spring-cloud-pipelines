import javaposse.jobdsl.dsl.DslFactory

DslFactory factory = this

// remove::start[CF]
String repos = 'https://github.com/marcingrzejszczak/github-analytics,https://github.com/marcingrzejszczak/github-webhook'
// remove::end[CF]

// remove::start[K8S]
String kubernetesRepos = 'https://github.com/marcingrzejszczak/github-analytics-kubernetes,https://github.com/marcingrzejszczak/github-webhook-kubernetes'
// remove::end[K8S]

// meta-seed
factory.job('meta-seed') {
	scm {
		git {
			remote {
				github('spring-cloud/spring-cloud-pipelines')
			}
			branch('${TOOLS_BRANCH}')
			extensions {
				submoduleOptions {
					recursive()
				}
			}
		}
	}
	steps {
		gradle("clean build")
		dsl {
			external('jenkins/seed/jenkins_pipeline.groovy')
			removeAction('DISABLE')
			removeViewAction('DELETE')
			ignoreExisting(false)
			lookupStrategy('SEED_JOB')
			additionalClasspath([
				'jenkins/src/main/groovy', 'jenkins/src/main/resources'
			].join("\n"))
		}
	}
	wrappers {
		parameters {
			stringParam('TOOLS_BRANCH', 'master', "The branch with pipeline functions")
		}
	}
}

// remove::start[CF]
factory.job('jenkins-pipeline-cf-seed') {
	scm {
		git {
			remote {
				github('spring-cloud/spring-cloud-pipelines')
			}
			branch('${TOOLS_BRANCH}')
			extensions {
				submoduleOptions {
					recursive()
				}
			}
		}
	}
	wrappers {
		parameters {
			// Common
			stringParam('REPOS', repos,
				"Provide a comma separated list of repos. If you want the project name to be different then repo name, " +
					"first provide the name and separate the url with \$ sign")
			stringParam('GIT_CREDENTIAL_ID', 'git', 'ID of the credentials used to push tags to git repo')
			stringParam('JDK_VERSION', 'jdk8', 'ID of Git installation')
			stringParam('M2_SETTINGS_REPO_ID', 'artifactory-local', "Name of the server ID in Maven's settings.xml")
			stringParam('REPO_WITH_BINARIES_FOR_UPLOAD', 'http://artifactory:8081/artifactory/libs-release-local', "Address to hosted JARs")
			stringParam('GIT_EMAIL', 'email@example.com', "Email used to tag the repo")
			stringParam('GIT_NAME', 'Pivo Tal', "Name used to tag the repo")
			stringParam('APP_MEMORY_LIMIT', '256m', "How much memory should be used by the infra apps (Eureka, Stub Runner etc.) ")
			stringParam('TOOLS_REPOSITORY', 'https://github.com/spring-cloud/spring-cloud-pipelines', "The URL containing pipeline functions repository")
			stringParam('TOOLS_BRANCH', 'master', "The branch with pipeline functions")
			booleanParam('AUTO_DEPLOY_TO_STAGE', false, 'Should deployment to stage be automatic')
			booleanParam('AUTO_DEPLOY_TO_PROD', false, 'Should deployment to prod be automatic')
			booleanParam('API_COMPATIBILITY_STEP_REQUIRED', true, 'Should api compatibility step be present')
			booleanParam('DB_ROLLBACK_STEP_REQUIRED', true, 'Should DB rollback step be present')
			booleanParam('DEPLOY_TO_STAGE_STEP_REQUIRED', true, 'Should deploy to stage step be present')
			stringParam('PAAS_TYPE', 'cf', "Which PAAS do you want to choose")

			stringParam('PAAS_TEST_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for test env')
			stringParam('PAAS_STAGE_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for stage env')
			stringParam('PAAS_PROD_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for prod env')
			stringParam('PAAS_TEST_ORG', 'pcfdev-org', 'Name of the CF organization for test env')
			stringParam('PAAS_TEST_SPACE_PREFIX', 'pcfdev-test', 'Prefix of the name of the CF space for the test env to which the app name will be appended')
			stringParam('PAAS_STAGE_ORG', 'pcfdev-org', 'Name of the CF organization for stage env')
			stringParam('PAAS_STAGE_SPACE', 'pcfdev-stage', 'Name of the CF space for stage env')
			stringParam('PAAS_PROD_ORG', 'pcfdev-org', 'Name of the CF organization for prod env')
			stringParam('PAAS_PROD_SPACE', 'pcfdev-prod', 'Name of the CF space for prod env')
			stringParam('JAVA_BUILDPACK_URL', 'https://github.com/cloudfoundry/java-buildpack.git#v3.8.1', "The URL to the Java buildpack to be used by CF")
			stringParam('PAAS_TEST_CREDENTIAL_ID', 'cf-test', 'ID of the CF credentials for test environment')
			stringParam('PAAS_STAGE_CREDENTIAL_ID', 'cf-stage', 'ID of the CF credentials for stage environment')
			stringParam('PAAS_PROD_CREDENTIAL_ID', 'cf-prod', 'ID of the CF credentials for prod environment')
			stringParam('PAAS_HOSTNAME_UUID', '', "Additional suffix for the route. In a shared environment the default routes can be already taken")
		}
	}
	steps {
		gradle("clean build")
		dsl {
			external('jenkins/jobs/jenkins_pipeline_sample*.groovy')
			external('jenkins/jobs/jenkins_pipeline_jenkinsfile_sample.groovy')
			removeAction('DISABLE')
			removeViewAction('DELETE')
			ignoreExisting(false)
			lookupStrategy('SEED_JOB')
			additionalClasspath([
				'jenkins/src/main/groovy', 'jenkins/src/main/resources'
			].join("\n"))
		}
	}
}
// remove::end[CF]
// remove::start[K8S]
factory.job('jenkins-pipeline-k8s-seed') {
	scm {
		git {
			remote {
				github('spring-cloud/spring-cloud-pipelines')
			}
			branch('${TOOLS_BRANCH}')
			extensions {
				submoduleOptions {
					recursive()
				}
			}
		}
	}
	wrappers {
		parameters {
			// Common
			stringParam('REPOS', kubernetesRepos,
				"Provide a comma separated list of repos. If you want the project name to be different then repo name, " +
					"first provide the name and separate the url with \$ sign")
			stringParam('GIT_CREDENTIAL_ID', 'git', 'ID of the credentials used to push tags to git repo')
			stringParam('JDK_VERSION', 'jdk8', 'ID of Git installation')
			stringParam('M2_SETTINGS_REPO_ID', 'artifactory-local', "Name of the server ID in Maven's settings.xml")
			stringParam('REPO_WITH_BINARIES_FOR_UPLOAD', 'http://artifactory:8081/artifactory/libs-release-local', "Address to hosted JARs")
			stringParam('GIT_EMAIL', 'email@example.com', "Email used to tag the repo")
			stringParam('GIT_NAME', 'Pivo Tal', "Name used to tag the repo")
			stringParam('APP_MEMORY_LIMIT', '256m', "How much memory should be used by the infra apps (Eureka, Stub Runner etc.) ")
			stringParam('TOOLS_REPOSITORY', 'https://github.com/spring-cloud/spring-cloud-pipelines', "The URL containing pipeline functions repository")
			stringParam('TOOLS_BRANCH', 'master', "The branch with pipeline functions")
			booleanParam('AUTO_DEPLOY_TO_STAGE', false, 'Should deployment to stage be automatic')
			booleanParam('AUTO_DEPLOY_TO_PROD', false, 'Should deployment to prod be automatic')
			booleanParam('API_COMPATIBILITY_STEP_REQUIRED', true, 'Should api compatibility step be present')
			booleanParam('DB_ROLLBACK_STEP_REQUIRED', true, 'Should DB rollback step be present')
			booleanParam('DEPLOY_TO_STAGE_STEP_REQUIRED', true, 'Should deploy to stage step be present')
			stringParam('PAAS_TYPE', 'k8s', "Which PAAS do you want to choose")
			booleanParam('KUBERNETES_MINIKUBE', true, 'Will you connect to Minikube?')

			stringParam('DOCKER_REGISTRY_ORGANIZATION', 'scpipelines', 'URL to Kubernetes cluster for test env')
			stringParam('PAAS_TEST_API_URL', '192.168.99.100:8443', 'URL to Kubernetes cluster for test env')
			stringParam('PAAS_STAGE_API_URL', '192.168.99.100:8443', 'URL to Kubernetes cluster for stage env')
			stringParam('PAAS_PROD_API_URL', '192.168.99.100:8443', 'URL to Kubernetes cluster for prod env')
			stringParam('PAAS_TEST_CA_PATH', '/usr/share/jenkins/cert/ca.crt', "Certificate Authority location for test env")
			stringParam('PAAS_STAGE_CA_PATH', '/usr/share/jenkins/cert/ca.crt', "Certificate Authority location for stage env")
			stringParam('PAAS_PROD_CA_PATH', '/usr/share/jenkins/cert/ca.crt', "Certificate Authority location for prod env")
			stringParam('PAAS_TEST_CLIENT_CERT_PATH', '/usr/share/jenkins/cert/apiserver.crt', "Client Certificate location for test env")
			stringParam('PAAS_STAGE_CLIENT_CERT_PATH', '/usr/share/jenkins/cert/apiserver.crt', "Client Certificate location for stage env")
			stringParam('PAAS_PROD_CLIENT_CERT_PATH', '/usr/share/jenkins/cert/apiserver.crt', "Client Certificate location for prod env")
			stringParam('PAAS_TEST_CLIENT_KEY_PATH', '/usr/share/jenkins/cert/apiserver.key', "Client Key location for test env")
			stringParam('PAAS_STAGE_CLIENT_KEY_PATH', '/usr/share/jenkins/cert/apiserver.key', "Client Key location for stage env")
			stringParam('PAAS_PROD_CLIENT_KEY_PATH', '/usr/share/jenkins/cert/apiserver.key', "Client Key location for prod env")
			stringParam('PAAS_TEST_CLIENT_TOKEN_PATH', '', "Path to the file containing the token for test env")
			stringParam('PAAS_STAGE_CLIENT_TOKEN_PATH', '', "Path to the file containing the token for stage env")
			stringParam('PAAS_PROD_CLIENT_TOKEN_PATH', '', "Path to the file containing the token for prod env")
			stringParam('PAAS_TEST_CLIENT_TOKEN_ID', '', "ID of the credentials containing a token used by Kubectl for test env. Takes precedence over client key")
			stringParam('PAAS_STAGE_CLIENT_TOKEN_ID', '', "ID of the credentials containing a token used by Kubectl for stage env. Takes precedence over client key")
			stringParam('PAAS_PROD_CLIENT_TOKEN_ID', '', "ID of the credentials containing a token used by Kubectl for prod env. Takes precedence over client key")
			stringParam('PAAS_TEST_CLUSTER_NAME', 'minikube', "Name of the cluster for test env")
			stringParam('PAAS_STAGE_CLUSTER_NAME', 'minikube', "Name of the cluster for stage env")
			stringParam('PAAS_PROD_CLUSTER_NAME', 'minikube', "Name of the cluster for prod env")
			stringParam('PAAS_TEST_CLUSTER_USERNAME', 'minikube', "Username for the cluster for test env")
			stringParam('PAAS_STAGE_CLUSTER_USERNAME', 'minikube', "Username for the cluster for stage env")
			stringParam('PAAS_PROD_CLUSTER_USERNAME', 'minikube', "Username for the cluster for prod env")
			stringParam('PAAS_TEST_SYSTEM_NAME', 'minikube', "Name for the system for test env")
			stringParam('PAAS_STAGE_SYSTEM_NAME', 'minikube', "Name for the system for stage env")
			stringParam('PAAS_PROD_SYSTEM_NAME', 'minikube', "Name for the system for prod env")
			stringParam('PAAS_TEST_NAMESPACE', 'sc-pipelines-test', 'Namespace for the test env')
			stringParam('PAAS_STAGE_NAMESPACE', 'sc-pipelines-stage', 'Namespace for the stage env')
			stringParam('PAAS_PROD_NAMESPACE', 'sc-pipelines-prod', 'Namespace for the prod env')
		}
	}
	steps {
		gradle("clean build")
		dsl {
			external('jenkins/jobs/jenkins_pipeline_sample*.groovy')
			external('jenkins/jobs/jenkins_pipeline_jenkinsfile_sample.groovy')
			removeAction('DISABLE')
			removeViewAction('DELETE')
			ignoreExisting(false)
			lookupStrategy('SEED_JOB')
			additionalClasspath([
				'jenkins/src/main/groovy', 'jenkins/src/main/resources'
			].join("\n"))
		}
	}
}
// remove::end[K8S]

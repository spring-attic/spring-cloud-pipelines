import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

// These will be taken either from seed or global variables
PipelineDefaults defaults = new PipelineDefaults(binding.variables)

// Example of a version with date and time in the name
String pipelineVersion = binding.variables["PIPELINE_VERSION"] ?: '''1.0.0.M1-${GROOVY,script ="new Date().format('yyMMdd_HHmmss')"}-VERSION'''
String cronValue = "H H * * 7" //every Sunday - I guess you should run it more often ;)
// TODO: this doesn't scale too much
String testReports = ["**/surefire-reports/*.xml", "**/test-results/**/*.xml"].join(",")
String gitCredentials = binding.variables["GIT_CREDENTIAL_ID"] ?: "git"
String repoWithBinariesCredentials = binding.variables["REPO_WITH_BINARIES_CREDENTIAL_ID"] ?: ""
String jdkVersion = binding.variables["JDK_VERSION"] ?: "jdk8"
// remove::start[CF]
String cfTestCredentialId = binding.variables["PAAS_TEST_CREDENTIAL_ID"] ?: ""
String cfStageCredentialId = binding.variables["PAAS_STAGE_CREDENTIAL_ID"] ?: ""
String cfProdCredentialId = binding.variables["PAAS_PROD_CREDENTIAL_ID"] ?: ""
// remove::end[CF]
// remove::start[K8S]
String k8sTestTokenCredentialId= binding.variables["PAAS_TEST_CLIENT_TOKEN_ID"] ?: ""
String k8sStageTokenCredentialId= binding.variables["PAAS_STAGE_CLIENT_TOKEN_ID"] ?: ""
String k8sProdTokenCredentialId= binding.variables["PAAS_PROD_CLIENT_TOKEN_ID"] ?: ""
// remove::end[K8S]
String gitEmail = binding.variables["GIT_EMAIL"] ?: "pivo@tal.com"
String gitName = binding.variables["GIT_NAME"] ?: "Pivo Tal"
boolean autoStage = binding.variables["AUTO_DEPLOY_TO_STAGE"] == null ? false : Boolean.parseBoolean(binding.variables["AUTO_DEPLOY_TO_STAGE"])
boolean autoProd = binding.variables["AUTO_DEPLOY_TO_PROD"] == null ? false : Boolean.parseBoolean(binding.variables["AUTO_DEPLOY_TO_PROD"])
boolean apiCompatibilityStep = binding.variables["API_COMPATIBILITY_STEP_REQUIRED"] == null ? true : Boolean.parseBoolean(binding.variables["API_COMPATIBILITY_STEP_REQUIRED"])
boolean rollbackStep = binding.variables["DB_ROLLBACK_STEP_REQUIRED"] == null ? true : Boolean.parseBoolean(binding.variables["DB_ROLLBACK_STEP_REQUIRED"])
boolean stageStep = binding.variables["DEPLOY_TO_STAGE_STEP_REQUIRED"] == null ? true : Boolean.parseBoolean(binding.variables["DEPLOY_TO_STAGE_STEP_REQUIRED"])
String scriptsDir = binding.variables["SCRIPTS_DIR"] ?: "${WORKSPACE}/common/src/main/bash"
// TODO: Automate customization of this value
String toolsRepo = binding.variables["TOOLS_REPOSITORY"] ?: "https://github.com/spring-cloud/spring-cloud-pipelines"
String toolsBranch = binding.variables["TOOLS_BRANCH"] ?: "master"
// TODO: K8S - consider parametrization
// remove::start[K8S]
String mySqlRootCredential = binding.variables["MYSQL_ROOT_CREDENTIAL_ID"] ?: ""
String mySqlCredential = binding.variables["MYSQL_CREDENTIAL_ID"] ?: ""
// remove::end[K8S]


// we're parsing the REPOS parameter to retrieve list of repos to build
String repos = binding.variables["REPOS"] ?:
		["https://github.com/marcingrzejszczak/github-analytics",
		 "https://github.com/marcingrzejszczak/github-webhook"].join(",")
List<String> parsedRepos = repos.split(",")
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

	//  ======= JOBS =======
	dsl.job("${projectName}-build") {
		deliveryPipelineConfiguration('Build', 'Build and Upload')
		triggers {
			cron(cronValue)
			githubPush()
		}
		wrappers {
			deliveryPipelineVersion(pipelineVersion, true)
			environmentVariables(defaults.defaultEnvVars)
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
			credentialsBinding {
				if (repoWithBinariesCredentials) usernamePassword('M2_SETTINGS_REPO_USERNAME', 'M2_SETTINGS_REPO_PASSWORD', repoWithBinariesCredentials)
			}
		}
		jdk(jdkVersion)
		scm {
			git {
				remote {
					name('origin')
					url(fullGitRepo)
					branch('master')
					credentials(gitCredentials)
				}
				extensions {
					wipeOutWorkspace()
				}
			}
		}
		configure { def project ->
			// Adding user email and name here instead of global settings
			project / 'scm' / 'extensions' << 'hudson.plugins.git.extensions.impl.UserIdentity' {
				'email'(gitEmail)
				'name'(gitName)
			}
		}
		steps {
			shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
			shell('''#!/bin/bash 
		${WORKSPACE}/.git/tools/common/src/main/bash/build_and_upload.sh
		''')
		}
		publishers {
			archiveJunit(testReports)
			String nextProject = apiCompatibilityStep ?
				"${projectName}-build-api-check" :
				"${projectName}-test-env-deploy"
			downstreamParameterized {
				trigger(nextProject) {
					triggerWithNoParameters()
					parameters {
						currentBuild()
					}
				}
			}
			git {
				pushOnlyIfSuccess()
				tag('origin', "dev/\${PIPELINE_VERSION}") {
					create()
					update()
				}
			}
		}
	}

	if (apiCompatibilityStep) {

		dsl.job("${projectName}-build-api-check") {
			deliveryPipelineConfiguration('Build', 'API compatibility check')
			triggers {
				cron(cronValue)
				githubPush()
			}
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				environmentVariables(defaults.defaultEnvVars)
				timestamps()
				colorizeOutput()
				maskPasswords()
				timeout {
					noActivity(300)
					failBuild()
					writeDescription('Build failed due to timeout after {0} minutes of inactivity')
				}
			}
			jdk(jdkVersion)
			scm {
				git {
					remote {
						name('origin')
						url(fullGitRepo)
						branch('master')
						credentials(gitCredentials)
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
				shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/build_api_compatibility_check.sh
		''')
			}
			publishers {
				archiveJunit(testReports) {
					allowEmptyResults()
				}
				downstreamParameterized {
					trigger("${projectName}-test-env-deploy") {
						triggerWithNoParameters()
						parameters {
							currentBuild()
						}
					}
				}
			}
		}
	}

	dsl.job("${projectName}-test-env-deploy") {
		deliveryPipelineConfiguration('Test', 'Deploy to test')
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			environmentVariables(defaults.defaultEnvVars)
			credentialsBinding {
				// remove::start[CF]
				if (cfTestCredentialId) usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
				// remove::end[CF]
				// remove::start[K8S]
				// TODO: What to do about this?
				if (mySqlCredential) usernamePassword('MYSQL_USER', 'MYSQL_PASSWORD', mySqlCredential)
				if (mySqlRootCredential) usernamePassword('MYSQL_ROOT_USER', 'MYSQL_ROOT_PASSWORD', mySqlRootCredential)
				if(k8sTestTokenCredentialId) string("TOKEN", k8sTestTokenCredentialId)
				// remove::end[K8S]
			}
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
		}
		scm {
			git {
				remote {
					url(fullGitRepo)
					branch('dev/${PIPELINE_VERSION}')
				}
				extensions {
					wipeOutWorkspace()
				}
			}
		}
		steps {
			shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
			shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/test_deploy.sh
		''')
		}
		publishers {
			// remove::start[K8S]
			archiveArtifacts {
				pattern("**/build/**/k8s/*.yml")
				pattern("**/target/**/k8s/*.yml")
				// remove::start[CF]
				allowEmpty()
				// remove::end[CF]
			}
			// end::start[K8S]
			downstreamParameterized {
				trigger("${projectName}-test-env-test") {
					parameters {
						currentBuild()
					}
					triggerWithNoParameters()
				}
			}
		}
	}

	dsl.job("${projectName}-test-env-test") {
		deliveryPipelineConfiguration('Test', 'Tests on test')
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			environmentVariables(defaults.defaultEnvVars)
			credentialsBinding {
				// remove::start[CF]
				if (cfTestCredentialId) usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
				// remove::end[CF]
				// remove::start[K8S]
				if (k8sTestTokenCredentialId) string("TOKEN", k8sTestTokenCredentialId)
				// remove::end[K8S]
			}
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
		}
		scm {
			git {
				remote {
					url(fullGitRepo)
					branch('dev/${PIPELINE_VERSION}')
				}
				extensions {
					wipeOutWorkspace()
				}
			}
		}
		steps {
			shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
			shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/test_smoke.sh
		''')
		}
		publishers {
			archiveJunit(testReports)
			if (rollbackStep) {
				downstreamParameterized {
					trigger("${projectName}-test-env-rollback-deploy") {
						parameters {
							currentBuild()
						}
						triggerWithNoParameters()
					}
				}
			} else {
				String stepName = stageStep ? "stage" : "prod"
				downstreamParameterized {
					trigger("${projectName}-${stepName}-env-deploy") {
						parameters {
							currentBuild()
						}
						triggerWithNoParameters()
					}
				}
			}
		}
	}

	if (rollbackStep) {
		dsl.job("${projectName}-test-env-rollback-deploy") {
			deliveryPipelineConfiguration('Test', 'Deploy to test latest prod version')
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				environmentVariables {
					environmentVariables(defaults.defaultEnvVars)
				}
				credentialsBinding {
					// remove::start[CF]
					if (cfTestCredentialId) usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
					// remove::end[CF]
					// remove::start[K8S]
					if (k8sTestTokenCredentialId) string("TOKEN", k8sTestTokenCredentialId)
					// remove::end[K8S]
				}
				timeout {
					noActivity(300)
					failBuild()
					writeDescription('Build failed due to timeout after {0} minutes of inactivity')
				}
			}
			scm {
				git {
					remote {
						url(fullGitRepo)
						branch('dev/${PIPELINE_VERSION}')
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
				shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/test_rollback_deploy.sh
		''')
			}
			publishers {
				// remove::start[K8S]
				archiveArtifacts {
					pattern("**/build/**/k8s/*.yml")
					pattern("**/target/**/k8s/*.yml")
					// remove::start[CF]
					allowEmpty()
					// remove::end[CF]
				}
				// end::start[K8S]
				downstreamParameterized {
					trigger("${projectName}-test-env-rollback-test") {
						triggerWithNoParameters()
						parameters {
							currentBuild()
						}
					}
				}
			}
		}

		dsl.job("${projectName}-test-env-rollback-test") {
			deliveryPipelineConfiguration('Test', 'Tests on test latest prod version')
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				environmentVariables {
					environmentVariables(defaults.defaultEnvVars)
				}
				credentialsBinding {
					// remove::start[CF]
					if (cfTestCredentialId) usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
					// remove::end[CF]
					// remove::start[K8S]
					if (k8sStageTokenCredentialId) string("TOKEN", k8sStageTokenCredentialId)
					// remove::end[K8S]
				}
				parameters {
					stringParam('LATEST_PROD_TAG', 'master', 'Latest production tag. If "master" is picked then the step will be ignored')
				}
				timestamps()
				colorizeOutput()
				maskPasswords()
				timeout {
					noActivity(300)
					failBuild()
					writeDescription('Build failed due to timeout after {0} minutes of inactivity')
				}
			}
			scm {
				git {
					remote {
						url(fullGitRepo)
						branch('${LATEST_PROD_TAG}')
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
				shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/test_rollback_smoke.sh
		''')
			}
			publishers {
				archiveJunit(testReports) {
					allowEmptyResults()
				}
				if(stageStep) {
					String nextJob = "${projectName}-stage-env-deploy"
					if (autoStage) {
						downstreamParameterized {
							trigger(nextJob) {
								parameters {
									currentBuild()
								}
							}
						}
					} else {
						buildPipelineTrigger(nextJob) {
							parameters {
								currentBuild()
							}
						}
					}
				} else {
						String nextJob = "${projectName}-prod-env-deploy"
						if (autoProd) {
							downstreamParameterized {
								trigger(nextJob) {
									parameters {
										currentBuild()
									}
								}
							}
						} else {
							buildPipelineTrigger(nextJob) {
								parameters {
									currentBuild()
								}
							}
						}
				}
			}
		}
	}

	if (stageStep) {
		dsl.job("${projectName}-stage-env-deploy") {
			deliveryPipelineConfiguration('Stage', 'Deploy to stage')
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				maskPasswords()
				environmentVariables {
					environmentVariables(defaults.defaultEnvVars)
				}
				credentialsBinding {
					// remove::start[CF]
					if (cfStageCredentialId) usernamePassword('PAAS_STAGE_USERNAME', 'PAAS_STAGE_PASSWORD', cfStageCredentialId)
					if (mySqlCredential) usernamePassword('MYSQL_USER', 'MYSQL_PASSWORD', mySqlCredential)
					if (mySqlRootCredential) usernamePassword('MYSQL_ROOT_USER', 'MYSQL_ROOT_PASSWORD', mySqlRootCredential)
					// remove::end[CF]
					// remove::start[K8S]
					if(k8sStageTokenCredentialId) string("TOKEN", k8sStageTokenCredentialId)
					// remove::end[K8S]
				}
				timestamps()
				colorizeOutput()
				maskPasswords()
				timeout {
					noActivity(300)
					failBuild()
					writeDescription('Build failed due to timeout after {0} minutes of inactivity')
				}
			}
			scm {
				git {
					remote {
						url(fullGitRepo)
						branch('dev/${PIPELINE_VERSION}')
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
				shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/stage_deploy.sh
		''')
			}
			publishers {
				// remove::start[K8S]
				archiveArtifacts {
					pattern("**/build/**/k8s/*.yml")
					pattern("**/target/**/k8s/*.yml")
					// remove::start[CF]
					allowEmpty()
					// remove::end[CF]
				}
				// end::start[K8S]
				if (autoStage) {
					downstreamParameterized {
						trigger("${projectName}-stage-env-test") {
							triggerWithNoParameters()
							parameters {
								currentBuild()
							}
						}
					}
				} else {
					buildPipelineTrigger("${projectName}-stage-env-test") {
						parameters {
							currentBuild()
						}
					}
				}
			}
		}

		dsl.job("${projectName}-stage-env-test") {
			deliveryPipelineConfiguration('Stage', 'End to end tests on stage')
			wrappers {
				deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
				environmentVariables {
					environmentVariables(defaults.defaultEnvVars)
				}
				credentialsBinding {
					// remove::start[CF]
					if (cfStageCredentialId) usernamePassword('PAAS_STAGE_USERNAME', 'PAAS_STAGE_PASSWORD', cfStageCredentialId)
					// remove::end[CF]
					// remove::start[K8S]
					if(k8sStageTokenCredentialId) string("TOKEN", k8sStageTokenCredentialId)
					// remove::end[K8S]
				}
				timestamps()
				colorizeOutput()
				maskPasswords()
				timeout {
					noActivity(300)
					failBuild()
					writeDescription('Build failed due to timeout after {0} minutes of inactivity')
				}
			}
			scm {
				git {
					remote {
						url(fullGitRepo)
						branch('dev/${PIPELINE_VERSION}')
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
				shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/stage_e2e.sh
		''')
			}
			publishers {
				archiveJunit(testReports)
				String nextJob = "${projectName}-prod-env-deploy"
				if (autoProd) {
					downstreamParameterized {
						trigger(nextJob) {
							parameters {
								currentBuild()
							}
						}
					}
				} else {
					buildPipelineTrigger(nextJob) {
						parameters {
							currentBuild()
						}
					}
				}
			}
		}
	}

	dsl.job("${projectName}-prod-env-deploy") {
		deliveryPipelineConfiguration('Prod', 'Deploy to prod')
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			maskPasswords()
			environmentVariables(defaults.defaultEnvVars)
			credentialsBinding {
				// remove::start[CF]
				if (cfProdCredentialId) usernamePassword('PAAS_PROD_USERNAME', 'PAAS_PROD_PASSWORD', cfProdCredentialId)
				// remove::end[CF]
				// remove::start[K8S]
				if (k8sProdTokenCredentialId) string("TOKEN", k8sProdTokenCredentialId)
				// remove::end[K8S]
			}
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
		}
		scm {
			git {
				remote {
					name('origin')
					url(fullGitRepo)
					branch('dev/${PIPELINE_VERSION}')
					credentials(gitCredentials)
				}
				extensions {
					wipeOutWorkspace()
				}
			}
		}
		configure { def project ->
			// Adding user email and name here instead of global settings
			project / 'scm' / 'extensions' << 'hudson.plugins.git.extensions.impl.UserIdentity' {
				'email'(gitEmail)
				'name'(gitName)
			}
		}
		steps {
			shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
			shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/prod_deploy.sh
		''')
		}
		publishers {
			// remove::start[K8S]
			archiveArtifacts {
				pattern("**/build/**/k8s/*.yml")
				pattern("**/target/**/k8s/*.yml")
				// remove::start[CF]
				allowEmpty()
				// remove::end[CF]
			}
			// end::start[K8S]
			buildPipelineTrigger("${projectName}-prod-env-complete") {
				parameters {
					currentBuild()
				}
			}
			git {
				forcePush(true)
				pushOnlyIfSuccess()
				tag('origin', "prod/\${PIPELINE_VERSION}") {
					create()
					update()
				}
			}
		}
	}

	dsl.job("${projectName}-prod-env-complete") {
		deliveryPipelineConfiguration('Prod', 'Complete switch over')
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			maskPasswords()
			environmentVariables(defaults.defaultEnvVars)
			credentialsBinding {
				// remove::start[CF]
				if (cfProdCredentialId) usernamePassword('PAAS_PROD_USERNAME', 'PAAS_PROD_PASSWORD', cfProdCredentialId)
				// remove::end[CF]
				// remove::start[K8S]
				if(k8sTestTokenCredentialId) string("TOKEN", k8sTestTokenCredentialId)
				// remove::end[K8S]
			}
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
		}
		scm {
			git {
				remote {
					name('origin')
					url(fullGitRepo)
					branch('dev/${PIPELINE_VERSION}')
					credentials(gitCredentials)
				}
				extensions {
					wipeOutWorkspace()
				}
			}
		}
		steps {
			shell("""#!/bin/bash
		rm -rf .git/tools && git clone -b ${toolsBranch} --single-branch ${toolsRepo} .git/tools 
		""")
			shell('''#!/bin/bash
		${WORKSPACE}/.git/tools/common/src/main/bash/prod_complete.sh
		''')
		}
	}
}

//  ======= JOBS =======

/**
 * A helper class to provide delegation for Closures. That way your IDE will help you in defining parameters.
 * Also it contains the default env vars setting
 */
class PipelineDefaults {

	final Map<String, String> defaultEnvVars

	PipelineDefaults(Map<String, String> variables) {
		this.defaultEnvVars = defaultEnvVars(variables)
	}

	private Map<String, String> defaultEnvVars(Map<String, String> variables) {
		Map<String, String> envs = [:]
		setIfPresent(envs, variables, "PAAS_TYPE")
		setIfPresent(envs, variables, "TOOLS_BRANCH")
		setIfPresent(envs, variables, "M2_SETTINGS_REPO_ID")
		setIfPresent(envs, variables, "REPO_WITH_BINARIES_FOR_UPLOAD")
		// remove::start[CF]
		setIfPresent(envs, variables, "PAAS_TEST_API_URL")
		setIfPresent(envs, variables, "PAAS_STAGE_API_URL")
		setIfPresent(envs, variables, "PAAS_PROD_API_URL")
		setIfPresent(envs, variables, "PAAS_TEST_ORG")
		setIfPresent(envs, variables, "PAAS_TEST_SPACE_PREFIX")
		setIfPresent(envs, variables, "PAAS_STAGE_ORG")
		setIfPresent(envs, variables, "PAAS_STAGE_SPACE")
		setIfPresent(envs, variables, "PAAS_PROD_ORG")
		setIfPresent(envs, variables, "PAAS_PROD_SPACE")
		setIfPresent(envs, variables, "PAAS_HOSTNAME_UUID")
		setIfPresent(envs, variables, "APP_MEMORY_LIMIT")
		setIfPresent(envs, variables, "JAVA_BUILDPACK_URL")
		// remove::end[CF]
		// remove::start[K8S]
		setIfPresent(envs, variables, "DOCKER_REGISTRY_ORGANIZATION")
		setIfPresent(envs, variables, "PAAS_TEST_API_URL")
		setIfPresent(envs, variables, "PAAS_STAGE_API_URL")
		setIfPresent(envs, variables, "PAAS_PROD_API_URL")
		setIfPresent(envs, variables, "PAAS_TEST_CA_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CA_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CA_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_STAGE_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_PROD_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_TEST_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_STAGE_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_PROD_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_TEST_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_STAGE_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_PROD_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_TEST_NAMESPACE")
		setIfPresent(envs, variables, "PAAS_STAGE_NAMESPACE")
		setIfPresent(envs, variables, "PAAS_PROD_NAMESPACE")
		setIfPresent(envs, variables, "KUBERNETES_MINIKUBE")
		// remove::end[K8S]
		println "Will analyze the following variables psased to the seed job \n\n${variables}"
		println "Will set the following env vars to the generated jobs \n\n${envs}"
		return envs
	}

	private static void setIfPresent(Map<String, String> envs, Map<String, String> variables, String prop) {
		if (variables[prop]) {
			envs[prop] = variables[prop]
		}
	}
}

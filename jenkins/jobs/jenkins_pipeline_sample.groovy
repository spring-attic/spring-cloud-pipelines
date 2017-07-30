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
String repoWithBinariesCredentials = binding.variables["REPO_WITH_BINARIES_CREDENTIALS_ID"] ?: "repo-with-binaries"
String jdkVersion = binding.variables["JDK_VERSION"] ?: "jdk8"
String cfTestCredentialId = binding.variables["PAAS_TEST_CREDENTIAL_ID"] ?: "cf-test"
String cfStageCredentialId = binding.variables["PAAS_STAGE_CREDENTIAL_ID"] ?: "cf-stage"
String cfProdCredentialId = binding.variables["PAAS_PROD_CREDENTIAL_ID"] ?: "cf-prod"
String gitEmail = binding.variables["GIT_EMAIL"] ?: "pivo@tal.com"
String gitName = binding.variables["GIT_NAME"] ?: "Pivo Tal"
boolean autoStage = binding.variables["AUTO_DEPLOY_TO_STAGE"] == null ? false : Boolean.parseBoolean(binding.variables["AUTO_DEPLOY_TO_STAGE"])
boolean autoProd = binding.variables["AUTO_DEPLOY_TO_PROD"] == null ? false : Boolean.parseBoolean(binding.variables["AUTO_DEPLOY_TO_PROD"])
boolean rollbackStep = binding.variables["ROLLBACK_STEP_REQUIRED"] == null ? true : Boolean.parseBoolean(binding.variables["ROLLBACK_STEP_REQUIRED"])
boolean stageStep = binding.variables["DEPLOY_TO_STAGE_STEP_REQUIRED"] == null ? true : Boolean.parseBoolean(binding.variables["DEPLOY_TO_STAGE_STEP_REQUIRED"])
String scriptsDir = binding.variables["SCRIPTS_DIR"] ?: "${WORKSPACE}/common/src/main/bash"
// TODO: Automate customization of this value
String toolsRepo = binding.variables["TOOLS_REPOSITORY"] ?: "https://github.com/spring-cloud/spring-cloud-pipelines"
String toolsBranch = binding.variables["TOOLS_BRANCH"] ?: "master"


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
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
			}
			timestamps()
			colorizeOutput()
			maskPasswords()
			timeout {
				noActivity(300)
				failBuild()
				writeDescription('Build failed due to timeout after {0} minutes of inactivity')
			}
			credentialsBinding {
				usernamePassword('M2_SETTINGS_REPO_USERNAME', 'M2_SETTINGS_REPO_PASSWORD', repoWithBinariesCredentials)
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
			downstreamParameterized {
				trigger("${projectName}-build-api-check") {
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

	dsl.job("${projectName}-build-api-check") {
		deliveryPipelineConfiguration('Build', 'API compatibility check')
		triggers {
			cron(cronValue)
			githubPush()
		}
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
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

	dsl.job("${projectName}-test-env-deploy") {
		deliveryPipelineConfiguration('Test', 'Deploy to test')
		wrappers {
			deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
			}
			credentialsBinding {
				usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
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
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
			}
			credentialsBinding {
				usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
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
					usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
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
					usernamePassword('PAAS_TEST_USERNAME', 'PAAS_TEST_PASSWORD', cfTestCredentialId)
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
					usernamePassword('PAAS_STAGE_USERNAME', 'PAAS_STAGE_PASSWORD', cfStageCredentialId)
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
					usernamePassword('PAAS_STAGE_USERNAME', 'PAAS_STAGE_PASSWORD', cfStageCredentialId)
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
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
			}
			credentialsBinding {
				usernamePassword('PAAS_PROD_USERNAME', 'PAAS_PROD_PASSWORD', cfProdCredentialId)
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
			environmentVariables {
				environmentVariables(defaults.defaultEnvVars)
			}
			credentialsBinding {
				usernamePassword('PAAS_PROD_USERNAME', 'PAAS_PROD_PASSWORD', cfProdCredentialId)
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
		envs['PAAS_TEST_API_URL'] = variables['PAAS_TEST_API_URL'] ?: 'api.local.pcfdev.io'
		envs['PAAS_STAGE_API_URL'] = variables['PAAS_STAGE_API_URL'] ?: 'api.local.pcfdev.io'
		envs['PAAS_PROD_API_URL'] = variables['PAAS_PROD_API_URL'] ?: 'api.local.pcfdev.io'
		envs['PAAS_TEST_ORG'] = variables['PAAS_TEST_ORG'] ?: 'pcfdev-org'
		envs['PAAS_TEST_SPACE'] = variables['PAAS_TEST_SPACE'] ?: 'pfcdev-test'
		envs['PAAS_STAGE_ORG'] = variables['PAAS_STAGE_ORG'] ?: 'pcfdev-org'
		envs['PAAS_STAGE_SPACE'] = variables['PAAS_STAGE_SPACE'] ?: 'pfcdev-stage'
		envs['PAAS_PROD_ORG'] = variables['PAAS_PROD_ORG'] ?: 'pcfdev-org'
		envs['PAAS_PROD_SPACE'] = variables['PAAS_PROD_SPACE'] ?: 'pfcdev-prod'
		envs['PAAS_HOSTNAME_UUID'] = variables['PAAS_HOSTNAME_UUID'] ?: ''
		envs['M2_SETTINGS_REPO_ID'] = variables['M2_SETTINGS_REPO_ID'] ?: 'artifactory-local'
		envs['REPO_WITH_BINARIES'] = variables['REPO_WITH_BINARIES'] ?: 'http://artifactory:8081/artifactory/libs-release-local'
		envs['APP_MEMORY_LIMIT'] = variables['APP_MEMORY_LIMIT'] ?: '256m'
		envs['JAVA_BUILDPACK_URL'] = variables['JAVA_BUILDPACK_URL'] ?: 'https://github.com/cloudfoundry/java-buildpack.git#v3.8.1'
		envs['PAAS_TYPE'] = variables['PAAS_TYPE'] ?: 'cf'
		return envs
	}

}

import javaposse.jobdsl.dsl.DslFactory

/*
	INTRODUCTION:

	The projects involved in the sample pipeline are:
	- Github-Analytics - the app that has a REST endpoint and uses messaging. Our app under test
		- https://github.com/dsyer/github-analytics
	- Eureka - simple Eureka Server
		- https://github.com/marcingrzejszczak/github-eureka
	- Github Analytics Stub Runner Boot - Stub Runner Boot server to be used for tests with Github Analytics. Uses Eureka and Messaging.
		- https://github.com/marcingrzejszczak/github-analytics-stub-runner-boot

	Also there's another project:
	- Github Webhook - project that uses Github-Analytics
		- https://github.com/marcingrzejszczak/atom-feed

	TODO BEFORE RUNNING THE PIPELINE

	- define the `Artifact Resolver` Global Configuration. I.e. point to your Nexus / Artifactory
	- click the `Allow token macro processing` in the Jenkins configuration
	- define the aforementioned masked env vars
	- customize the java version
	- add a Credential to allow pushing the Git tag. Credential is called 'git'
	- setup `Config File Management` to ensure that every slave has the Maven's settings.xml set up.
		Otherwise `./mvnw clean deploy` won't work
	- if you can't see ${PIPELINE_VERSION} being resolved in the initial job, check the logs

	WARNING: Skipped parameter `PIPELINE_VERSION` as it is undefined on `jenkins-pipeline-sample-build`.
	Set `-Dhudson.model.ParametersAction.keepUndefinedParameters`=true to allow undefined parameters
	to be injected as environment variables or
	`-Dhudson.model.ParametersAction.safeParameters=[comma-separated list]`
	to whitelist specific parameter names, even though it represents a security breach

	TODO: TO develop
	- convert all groovy functions into bash functions
	- move the functions to src/main/bash and write bash tests
	- resolve group / artifact / version ids from Maven instead of passing them
	- perform blue green deployment
	- implement the complete step
	- add tests for StubRunner + Eureka
*/

DslFactory dsl = this

//  ======= GLOBAL =======
// You need to pass the following as ENV VARS in Mask Passwords section
String cfTestUsername = '${CF_TEST_USERNAME}'
String cfTestPassword = '${CF_TEST_PASSWORD}'
String cfTestOrg = '${CF_TEST_ORG}'
String cfTestSpace = '${CF_TEST_SPACE}'
String cfStageUsername = '${CF_STAGE_USERNAME}'
String cfStagePassword = '${CF_STAGE_PASSWORD}'
String cfStageOrg = '${CF_STAGE_ORG}'
String cfStageSpace = '${CF_STAGE_SPACE}'
String cfProdUsername = '${CF_PROD_USERNAME}'
String cfProdPassword = '${CF_PROD_PASSWORD}'
String cfProdOrg = '${CF_PROD_ORG}'
String cfProdSpace = '${CF_PROD_SPACE}'
String repoWithJarsEnvVar = '${REPO_WITH_JARS}'

// Adjust this to be in accord with your installations
String jdkVersion = 'jdk8'
//  ======= GLOBAL =======

//  ======= PER REPO VARIABLES =======
String projectName = 'jenkins-pipeline-sample'
String organization = "dsyer"
String gitRepoName = "github-analytics"
String fullGitRepo = "https://github.com/${organization}/${gitRepoName}"
String cronValue = "H H * * 7" //every Sunday - I guess you should run it more often ;)
String gitCredentialsId = 'git'

// TODO: Change to sth like this
// Example of a version with date and time in the name
//String pipelineVersion = '${new Date().format("yyyyMMddHHss")}'
String pipelineVersion = '0.0.1.M1'

//  ======= PER REPO VARIABLES =======


//  ======= JOBS =======
dsl.job("${projectName}-build") {
	deliveryPipelineConfiguration('Build', 'Build and Upload')
	triggers {
		cron(cronValue)
		githubPush()
	}
	wrappers {
		// Example of a version with date and time in the name
		//deliveryPipelineVersion('${new Date().format("yyyyMMddHHss")}', true)
		deliveryPipelineVersion(pipelineVersion, true)
		environmentVariables {
			maskPasswords()
		}
		parameters {
			booleanParam('REDOWNLOAD_INFRA', false, "If Eureka & StubRunner & CF binaries should be redownloaded if already present")
			booleanParam('REDEPLOY_INFRA', false, "If Eureka & StubRunner binaries should be redeployed if already present")
			stringParam('EUREKA_GROUP_ID', 'com.example.eureka', "Group Id for Eureka used by tests")
			stringParam('EUREKA_ARTIFACT_ID', 'github-eureka', "Artifact Id for Eureka used by tests")
			stringParam('EUREKA_VERSION', '0.0.1.M1', "Artifact Version for Eureka used by tests")
			stringParam('STUBRUNNER_GROUP_ID', 'com.example.eureka', "Group Id for Stub Runner used by tests")
			stringParam('STUBRUNNER_ARTIFACT_ID', 'github-analytics-stub-runner-boot', "Artifact Id for Stub Runner used by tests")
			stringParam('STUBRUNNER_VERSION', '0.0.1.M1', "Artifact Version for Stub Runner used by tests")
		}
	}
	jdk(jdkVersion)
	scm {
		git {
			remote {
				name('origin')
				url(fullGitRepo)
				branch('master')
				credentials(gitCredentialsId)
			}
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell("""#!/bin/bash
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/build_and_upload.sh')}
		""")
	}
	publishers {
		archiveJunit('**/surefire-reports/*.xml')
		downstreamParameterized {
			trigger("${projectName}-test-env-deploy") {
				triggerWithNoParameters()
				parameters {
					currentBuild()
				}
			}
		}
		git {
			tag('origin', "dev/\${PIPELINE_VERSION}") {
				pushOnlyIfSuccess()
				create()
				update()
			}
		}
	}
}

dsl.job("${projectName}-test-env-deploy") {
	deliveryPipelineConfiguration('Test', 'Deploy to test')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
		maskPasswords()
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
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/test_deploy.sh')}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-test") {
				parameters {
					propertiesFile('target/test.properties', true)
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
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/test_smoke.sh')}
		""")
	}
	publishers {
		archiveJunit('**/surefire-reports/*.xml')
		downstreamParameterized {
			trigger("${projectName}-test-env-rollback-deploy") {
				parameters {
					currentBuild()
				}
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-test-env-rollback-deploy") {
	deliveryPipelineConfiguration('Test', 'Deploy to test latest prod version')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
		maskPasswords()
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
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/test_rollback_deploy.sh')}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-rollback-test") {
				triggerWithNoParameters()
				parameters {
					propertiesFile('target/test.properties', true)
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
		parameters {
			stringParam('LATEST_PROD_TAG', 'master', 'Latest production tag. If "master" is picked then the step will be ignored')
		}
	}
	scm {
		git {
			remote {
				url(fullGitRepo)
				branch('${LATEST_PROD_TAG}')
			}
		}
	}
	steps {
		shell("""#!/bin/bash
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/test_rollback_smoke.sh')}
		""")
	}
	publishers {
		archiveJunit('**/surefire-reports/*.xml') {
			allowEmptyResults()
		}
		downstreamParameterized {
			trigger("${projectName}-stage-env-deploy") {
				parameters {
					currentBuild()
				}
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-stage-env-deploy") {
	deliveryPipelineConfiguration('Stage', 'Deploy to stage')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
		maskPasswords()
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
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/stage_deploy.sh')}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-stage-env-test") {
				parameters {
					currentBuild()
					propertiesFile('target/test.properties', true)
				}
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-stage-env-test") {
	deliveryPipelineConfiguration('Stage', 'Tests on stage')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
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
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/stage_smoke.sh')}
		""")
	}
	publishers {
		archiveJunit('**/surefire-reports/*.xml')
		buildPipelineTrigger("${projectName}-prod-env-deploy") {
			parameters {
				currentBuild()
			}
		}
	}
}

dsl.job("${projectName}-prod-env-deploy") {
	deliveryPipelineConfiguration('Prod', 'Deploy to prod')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
		maskPasswords()
	}
	scm {
		git {
			remote {
				name('origin')
				url(fullGitRepo)
				branch('dev/${PIPELINE_VERSION}')
			}
		}
	}
	steps {
		shell("""#!/bin/bash
		set -e

		${readFileFromWorkspace('src/main/bash/pipeline.sh')}
		${readFileFromWorkspace('src/main/bash/prod_deploy.sh')}
		""")
	}
	publishers {
		buildPipelineTrigger("${projectName}-prod-env-complete") {
			parameters {
				currentBuild()
			}
		}
		git {
			tag('origin', "prod/\${PIPELINE_VERSION}") {
				pushOnlyIfSuccess()
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
	}
	steps {
		shell("""#!/bin/bash
			set - e

			${readFileFromWorkspace('src/main/bash/pipeline.sh') }
			${readFileFromWorkspace('src/main/bash/prod_complete.sh') }
		""")
	}
}

dsl.deliveryPipelineView("${projectName}-pipeline") {
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
//  ======= JOBS =======
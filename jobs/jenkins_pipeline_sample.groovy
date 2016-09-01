import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this


//  ======= GLOBAL =======
// You need to pass the following as ENV VARS in Mask Passwords section
String cfTestUsername = '$CF_TEST_USERNAME'
String cfTestPassword = '$CF_TEST_PASSWORD'
String cfTestOrg = '$CF_TEST_ORG'
String cfTestSpace = '$CF_TEST_SPACE'

String cfStageUsername = '$CF_STAGE_USERNAME'
String cfStagePassword = '$CF_STAGE_PASSWORD'
String cfStageOrg = '$CF_STAGE_ORG'
String cfStageSpace = '$CF_STAGE_SPACE'

String cfProdUsername = '$CF_PROD_USERNAME'
String cfProdPassword = '$CF_PROD_PASSWORD'
String cfProdOrg = '$CF_PROD_ORG'
String cfProdSpace = '$CF_PROD_SPACE'

// Adjust this to be in accord with your installations
String jdkVersion = 'jdk8'

/*
	Remember that you need to
	- define the `Artifact Resolver` Global Configuration. I.e. point to your Nexus / Artifactory
	- click the `Allow token macro processing` in the Jenkins configuration
	- define the aforementioned masked env vars
	- customize the java version
*/

//  ======= GLOBAL =======


//  ======= PER REPO VARIABLES =======
String projectName = 'jenkins-pipeline-sample'
String organization = "marcingrzejszczak"
String gitRepoName = "atom-feed"
String fullGitRepo = "https://github.com/${organization}/${gitRepoName}"
String projectGroupId = 'org.springframework.github'
String projectArtifactId = 'github-webhook'
String cronValue = "H H * * 7" //every Sunday - I guess you should run it more often ;)
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
		deliveryPipelineVersion('0.0.1.BUILD-SNAPSHOT', true)
	}
	jdk(jdkVersion)
	scm {
		git {
			remote {
				url(fullGitRepo)
				branch('master')
			}
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell('./mvnw clean verify deploy -Dversion=${PIPELINE_VERSION}')
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
			tag(fullGitRepo, "dev/\${PIPELINE_VERSION}") {
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
	steps {
		resolveArtifacts {
			failOnError()
			targetDirectory('target')
			artifact {
				groupId(projectGroupId)
				artifactId(projectArtifactId)
				version('${PIPELINE_VERSION}')
				extension('jar')
			}
		}
		shell("""\
		${logInToCf(cfTestUsername, cfTestPassword, cfTestOrg, cfTestSpace)}
		// setup infra
		${deployRabbitMqToCf()}
		// deploy spring cloud contract boot
		// deploy the app
		${deployAppWithName(projectArtifactId)}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-test") {
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
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell("echo 'Running tests on test env'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-stage-env-deploy") {
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
	steps {
		resolveArtifacts {
			failOnError()
			targetDirectory('target')
			artifact {
				groupId(projectGroupId)
				artifactId(projectArtifactId)
				version('${PIPELINE_VERSION}')
				extension('jar')
			}
		}
		shell("""\
		${logInToCf(cfStageUsername, cfStagePassword, cfStageOrg, cfStageSpace)}
		// setup infra
		${deployRabbitMqToCf()}
		// deploy spring cloud contract boot
		// deploy the app
		${deployAppWithName(projectArtifactId)}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-stage-env-test") {
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
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell("echo 'Running tests on stage env'")
	}
	publishers {
		buildPipelineTrigger("${projectName}-prod-env-deploy")
	}
}

dsl.job("${projectName}-prod-env-deploy") {
	deliveryPipelineConfiguration('Prod', 'Deploy to prod')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
		maskPasswords()
	}
	steps {
		resolveArtifacts {
			failOnError()
			targetDirectory('target')
			artifact {
				groupId(projectGroupId)
				artifactId(projectArtifactId)
				version('${PIPELINE_VERSION}')
				extension('jar')
			}
		}
		shell("""\
		${logInToCf(cfProdUsername, cfProdPassword, cfProdOrg, cfProdSpace)}
		// setup infra
		${deployRabbitMqToCf()}
		// deploy spring cloud contract boot
		// deploy the app
		${deployAppWithName(projectArtifactId)}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-prod-env-complete")
		}
		git {
			tag(fullGitRepo, "prod/\${PIPELINE_VERSION}") {
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
		shell("echo 'Disabling blue instance'")
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

//  ======= FUNCTIONS =======
String logInToCf(String cfUsername, String cfPassword, String cfOrg, String cfSpace) {
	return """
		echo "Downloading Cloud Foundry"
		curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx

		echo "Setting alias to cf"
		alias cf=`pwd`/cf
		export cf=`pwd`/cf

		echo "Cloud foundry version"
		cf --version

		echo "Logging in to CF"
		cf api --skip-ssl-validation api.run.pivotal.io
		cf login -u ${cfUsername} -p ${cfPassword} -o ${cfOrg} -s ${cfSpace}
	"""
}

String deployRabbitMqToCf(String rabbitMqAppName = "rabbitmq") {
	return """
		READY_FOR_TESTS="no"
		echo "Waiting for RabbitMQ to start"
		# create RabbitMQ
		APP_NAME="${rabbitMqAppName}"
		cf s | grep \${APP_NAME} && echo "found \${APP_NAME}" && READY_FOR_TESTS="yes" ||
			cf cs cloudamqp lemur \${APP_NAME} && echo "Started RabbitMQ" && READY_FOR_TESTS="yes" ||
			cf cs p-rabbitmq standard \${APP_NAME}  && echo "Started RabbitMQ for PCF Dev" && READY_FOR_TESTS="yes"

		if [[ "\${READY_FOR_TESTS}" == "no" ]] ; then
			echo "RabbitMQ failed to start..."
			exit 1
		fi
	"""
}

String deployAppWithName(String appName) {
	return """
	cf push ${appName} -m 1024m -i 1 -p target/${appName}-\${PIPELINE_VERSION}.jar -n ${appName} --no-start -b https://github.com/cloudfoundry/java-buildpack.git#v3.8.1
	APPLICATION_DOMAIN=`app_domain ${appName}`
	echo -e "\n\nDetermined that application_domain for $appName is \${APPLICATION_DOMAIN}\n\n"
	cf env ${appName} | grep APPLICATION_DOMAIN || cf set-env ${appName} APPLICATION_DOMAIN \${APPLICATION_DOMAIN}
	cf restart ${appName}
	"""
}
//  ======= FUNCTIONS =======
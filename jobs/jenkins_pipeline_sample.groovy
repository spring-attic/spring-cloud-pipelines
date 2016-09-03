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
	- add a Credential to allow pushing the Git tag
	- if you can't see ${PIPELINE_VERSION} being resolved in the initial job, check the logs

	WARNING: Skipped parameter `PIPELINE_VERSION` as it is undefined on `jenkins-pipeline-sample-build`.
	Set `-Dhudson.model.ParametersAction.keepUndefinedParameters`=true to allow undefined parameters
	to be injected as environment variables or
	`-Dhudson.model.ParametersAction.safeParameters=[comma-separated list]`
	to whitelist specific parameter names, even though it represents a security breach

	TODO: TO develop
	- change artifact resolution from plugin to standard wget / curl
*/

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
String repoWithJars = "http://repo.spring.io/libs-milestone"
//  ======= GLOBAL =======


//  ======= PER REPO VARIABLES =======
String projectName = 'jenkins-pipeline-sample'
String organization = "dsyer"
String gitRepoName = "github-analytics"
String fullGitRepo = "https://github.com/${organization}/${gitRepoName}"
String projectGroupId = 'com.example.github'
String projectArtifactId = gitRepoName
String cronValue = "H H * * 7" //every Sunday - I guess you should run it more often ;)
String gitCredentialsId = 'git'
// Discovery + Stub runner boot
String eurekaGroupId = 'com.example.eureka'
String eurekaArtifactId = 'github-eureka'
String eurekaVersion = '0.0.1.M1'
String stubRunnerBootGroupId = 'com.example.github'
String stubRunnerBootArtifactId = 'github-analytics-stub-runner-boot'
String stubRunnerBootVersion = '0.0.1.M1'

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
		environmentVariables {
			maskPasswords()
		}
	}
	jdk(jdkVersion)
	scm {
		git {
			remote {
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
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell("""\
		# Download all the necessary jars
		${downloadJar(repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		${downloadJar(repoWithJars, eurekaGroupId, eurekaArtifactId, eurekaVersion)}
		${downloadJar(repoWithJars, stubRunnerBootGroupId, stubRunnerBootArtifactId, stubRunnerBootVersion)}
		""")
		shell("""\
		${logInToCf(cfTestUsername, cfTestPassword, cfTestOrg, cfTestSpace)}
		# setup infra
		${deployRabbitMqToCf()}
		${deployEureka("${eurekaArtifactId-eurekaVersion}")}
		${deployStubRunnerBoot("${stubRunnerBootArtifactId-stubRunnerBootVersion}")}
		# deploy app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
		# retrieve host of the app / stubrunner
		# we have to store them in a file that will be picked as properties
		rm target/test.properties
		${appHost(projectArtifactId)}
		echo "application.url=\${APP_HOST}" >> target/test.properties
		${appHost('stubRunner')}
		echo "stubrunner.url=\${APP_HOST}" >> target/test.properties
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-test") {
				parameters {
					propertiesFile('target/test.properties')
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
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell('''#!/bin/bash\
		./mvnw clean install -Pintegration -Dapplication.url=${application.url} -Dstubrunner.url=${stubrunner.url}
		''')
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
		shell("""\
		# Download all the necessary jars
		${downloadJar(repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		${downloadJar(repoWithJars, eurekaGroupId, eurekaArtifactId, eurekaVersion)}
		${downloadJar(repoWithJars, stubRunnerBootGroupId, stubRunnerBootArtifactId, stubRunnerBootVersion)}
		""")
		shell("""\
		${logInToCf(cfStageUsername, cfStagePassword, cfStageOrg, cfStageSpace)}
		# setup infra
		${deployRabbitMqToCf()}
		${deployEureka("${eurekaArtifactId - eurekaVersion}")}
		${deployStubRunnerBoot("${stubRunnerBootArtifactId - stubRunnerBootVersion}")}
		# deploy app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
		# retrieve host of the app / stubrunner
		# we have to store them in a file that will be picked as properties
		rm target/test.properties
		${appHost(projectArtifactId)}
		echo "application.url=\${APP_HOST}" >> target/test.properties
		${appHost('stubRunner')}
		echo "stubrunner.url=\${APP_HOST}" >> target/test.properties
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-stage-env-test") {
				parameters {
					propertiesFile('target/test.properties')
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
			extensions {
				wipeOutWorkspace()
			}
		}
	}
	steps {
		shell('''#!/bin/bash\
		./mvnw clean install -Pintegration -Dapplication.url=${application.url} -Dstubrunner.url=${stubrunner.url}
		''')
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
		shell("""\
		# Download all the necessary jars
		${downloadJar(repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		""")
		shell("""\
		${logInToCf(cfProdUsername, cfProdPassword, cfProdOrg, cfProdSpace)}
		# setup infra
		${deployRabbitMqToCf()}
		${deployEureka("${eurekaArtifactId - eurekaVersion}")}
		# deploy the app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
		""")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-prod-env-complete")
		}
		git {
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

String deployAndRestartAppWithName(String appName, String jarName) {
	return """
	${deployAppWithName(appName, jarName)}
	${restartApp(appName)}
	"""
}

String appHost(String appName) {
	return """
	APP_HOST=`app_domain ${appName}`
	echo "\${APP_HOST}"
	"""
}

String deployAppWithName(String appName, String jarName) {
	return """
	cf push ${appName} -m 1024m -i 1 -p target/${jarName}.jar -n ${appName} --no-start -b https://github.com/cloudfoundry/java-buildpack.git#v3.8.1
	APPLICATION_DOMAIN=`cf apps | grep ${appName} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
	echo -e "\n\nDetermined that application_domain for $appName is \${APPLICATION_DOMAIN}\n\n"
	${setEnvVar(appName, 'APPLICATION_DOMAIN', '${APPLICATION_DOMAIN}')}
	${setEnvVar(appName, 'JAVA_OPTS', '-Djava.security.egd=file:///dev/urandom')}
	"""
}

String setEnvVar(String appName, String key, String value) {
	return "cf env ${appName} | grep ${key} || cf set-env ${appName} ${key} ${value}"
}

String restartApp(String appName) {
	return "cf restart ${appName}"
}

String deployEureka(String jarName) {
	return """
	${deployAppWithName("github-eureka", jarName)}
	${restartApp("github-eureka")}
	${createServiceWithName("github-eureka")}
	"""
}

String deployStubRunnerBoot(String jarName) {
	return """
	${deployAppWithName("stubRunner", jarName)}
	${extractMavenProperty("stubrunner.ids")}
	${setEnvVar("stubRunner", "stubrunner.ids", '${MAVEN_PROPERTY}')}
	${restartApp("stubRunner")}
	${createServiceWithName("stubRunner")}
	"""
}

String createServiceWithName(String name) {
	return """
	APPLICATION_DOMAIN=`cf apps | grep ${name} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
	JSON='{"uri":"http://'\${APPLICATION_DOMAIN}'"}'
	cf create-user-provided-service ${name} -p \${JSON}
	"""
}

// The function uses Maven Wrapper - if you're using Maven you have to have it on your classpath
// and change this function
String extractMavenProperty(String prop) {
	return """
			MAVEN_PROPERTY=\$(./mvnw -q \\
			-Dexec.executable="echo" \\
			-Dexec.args='\${${prop}}' \\
			--non-recursive \\
			org.codehaus.mojo:exec-maven-plugin:1.3.1:exec)
        """
}

// The values of group / artifact ids can be later retrieved from Maven
String downloadJar(String repoWithJars, String groupId, String artifactId, String version) {
	return """
	mkdir target --parents
	curl ${repoWithJars}/${groupId.replace(".", "/")}/${artifactId}/${version}/${artifactId}-${version}.jar -o target/${artifactId}-${version}.jar
	"""
}

//  ======= FUNCTIONS =======
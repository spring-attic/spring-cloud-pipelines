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
// TODO: Retrieve from maven
String projectGroupId = 'com.example.github'
// TODO: Retrieve from maven
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
		}
	}
	steps {
		shell("""#!/bin/bash
		set -e
		# Download all the necessary jars
		${downloadJar('true', repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		${downloadJar('${REDEPLOY_INFRA}', repoWithJars, eurekaGroupId, eurekaArtifactId, eurekaVersion)}
		${downloadJar('${REDEPLOY_INFRA}', repoWithJars, stubRunnerBootGroupId, stubRunnerBootArtifactId, stubRunnerBootVersion)}
		""")
		shell("""#!/bin/bash
		set -e
		${logInToCf('${REDOWNLOAD_INFRA}',cfTestUsername, cfTestPassword, cfTestOrg, cfTestSpace)}
		# setup infra
		${deployRabbitMqToCf()}
		${deployEureka('${REDEPLOY_INFRA}', "${eurekaArtifactId}-${eurekaVersion}")}
		${deployStubRunnerBoot('${REDEPLOY_INFRA}', "${stubRunnerBootArtifactId}-${stubRunnerBootVersion}")}
		# deploy app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
		${propagatePropertiesForTests(projectArtifactId)}
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
		shell(runSmokeTests())
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
		# Find latest prod version
		LATEST_PROD_TAG=\$( ${findLatestProdTag()} )
		echo "Last prod tag equals \${LATEST_PROD_TAG}"
		if [[ -z "\${LATEST_PROD_TAG}" ]]; then
			echo "No prod release took place - skipping this step"
		else
			# Downloading latest jar
			LATEST_PROD_VERSION=\${LATEST_PROD_TAG#prod/}
			echo "Last prod version equals \${LATEST_PROD_VERSION}"
			${downloadJar('true', repoWithJars, projectGroupId, projectArtifactId, '${LATEST_PROD_VERSION}')}
			${logInToCf('${REDOWNLOAD_INFRA}',cfTestUsername, cfTestPassword, cfTestOrg, cfTestSpace)}
			# deploy app
			${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${LATEST_PROD_VERSION}")}
			${propagatePropertiesForTests(projectArtifactId)}
			# Adding latest prod tag
			echo "LATEST_PROD_TAG=\${LATEST_PROD_TAG}" >> target/test.properties
		fi
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
		if [[ "\${LATEST_PROD_TAG}" == "master" ]]; then
			echo "No prod release took place - skipping this step"
		else
			${runSmokeTests()}
		fi
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
		# Download all the necessary jars
		${downloadJar('true', repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		${downloadJar('${REDEPLOY_INFRA}', repoWithJars, eurekaGroupId, eurekaArtifactId, eurekaVersion)}
		${downloadJar('${REDEPLOY_INFRA}', repoWithJars, stubRunnerBootGroupId, stubRunnerBootArtifactId, stubRunnerBootVersion)}
		""")
		shell("""#!/bin/bash
		set -e
		${logInToCf('${REDOWNLOAD_INFRA}',cfStageUsername, cfStagePassword, cfStageOrg, cfStageSpace)}
		# setup infra
		${deployRabbitMqToCf()}
		${deployEureka('${REDOWNLOAD_INFRA}', "${eurekaArtifactId}-${eurekaVersion}")}
		${deployStubRunnerBoot('${REDOWNLOAD_INFRA}', "${stubRunnerBootArtifactId}-${stubRunnerBootVersion}")}
		# deploy app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
		${propagatePropertiesForTests(projectArtifactId)}
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
		${runSmokeTests()}
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
		# Download all the necessary jars
		${downloadJar('true', repoWithJars, projectGroupId, projectArtifactId, '${PIPELINE_VERSION}')}
		""")
		shell("""#!/bin/bash
		set -e
		${logInToCf('${REDOWNLOAD_INFRA}',cfProdUsername, cfProdPassword, cfProdOrg, cfProdSpace)}
		# deploy the app
		${deployAndRestartAppWithName(projectArtifactId, "${projectArtifactId}-\${PIPELINE_VERSION}")}
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
String logInToCf(String redownloadInfra, String cfUsername, String cfPassword, String cfOrg, String cfSpace) {
	return """
		CF_INSTALLED=\$( cf --version || echo "false" )
		CF_DOWNLOADED=\$( test -r cf && echo "true" || echo "false" )
		if [[ \${CF_INSTALLED} == "false" && (\${CF_DOWNLOADED} == "false" || \${CF_DOWNLOADED} == "true" && ${redownloadInfra} == "true") ]]; then
			echo "Downloading Cloud Foundry"
			curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
			CF_DOWNLOADED="true"
		else
			echo "CF is already installed or was already downloaded but the flag to redownload was disabled"
		fi

		if [[ \${CF_DOWNLOADED} == "true" ]]; then
			echo "Adding CF to PATH"
			PATH=\${PATH}:`pwd`
			chmod +x cf
		fi

		echo "Cloud foundry version"
		cf --version

		echo "Logging in to CF"
		cf api --skip-ssl-validation api.run.pivotal.io
		cf login -u ${cfUsername} -p ${cfPassword} -o ${cfOrg} -s ${cfSpace}
	"""
}

String deployRabbitMqToCf(String rabbitMqAppName = "github-rabbitmq") {
	return """
		echo "Waiting for RabbitMQ to start"
		# create RabbitMQ
		APP_NAME="${rabbitMqAppName}"
		cf s | grep \${APP_NAME} && echo "found \${APP_NAME}" ||
			cf cs cloudamqp lemur \${APP_NAME} && echo "Started RabbitMQ" ||
			cf cs p-rabbitmq standard \${APP_NAME}  && echo "Started RabbitMQ for PCF Dev"
	"""
}

String deployAndRestartAppWithName(String appName, String jarName) {
	return """
	${deployAppWithName(appName, jarName, true)}
	${restartApp(appName)}
	"""
}

String appHost(String appName) {
	return """
	APP_HOST=`cf apps | grep ${appName.toLowerCase()} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
	echo "\${APP_HOST}"
	"""
}

String deployAppWithName(String appName, String jarName, boolean useManifest = false) {
	String lowerCaseAppName = appName.toLowerCase()
	return """
	cf push ${lowerCaseAppName} -m 1024m -i 1 -p target/${jarName}.jar -n ${lowerCaseAppName} --no-start -b https://github.com/cloudfoundry/java-buildpack.git#v3.8.1 ${useManifest ? '' : '--no-manifest'}
	APPLICATION_DOMAIN=`cf apps | grep ${lowerCaseAppName} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
	echo "Determined that application_domain for ${lowerCaseAppName} is \${APPLICATION_DOMAIN}"
	${setEnvVar(lowerCaseAppName, 'APPLICATION_DOMAIN', '${APPLICATION_DOMAIN}')}
	${setEnvVar(lowerCaseAppName, 'JAVA_OPTS', '-Djava.security.egd=file:///dev/urandom')}
	"""
}

String setEnvVarIfMissing(String appName, String key, String value) {
	return "cf env ${appName} | grep ${key} || ${setEnvVar(appName, key, value)}"
}

String setEnvVar(String appName, String key, String value) {
	return "cf set-env ${appName} ${key} ${value}"
}

String restartApp(String appName) {
	return "cf restart ${appName}"
}

String deployEureka(String redeploy, String jarName, String appName = "github-eureka") {
	return """
	if [[ ! -e target/${jarName}.jar || ( -e target/${jarName}.jar && ${redeploy} == "true" ) ]]; then
		${deployAppWithName(appName, jarName)}
		${restartApp(appName)}
		${createServiceWithName(appName)}
	else
		echo "The target/${jarName}.jar is missing or redeploy flag was turned off"
	fi
	"""
}

String deployStubRunnerBoot(String redeploy, String jarName, String eurekaService = "github-eureka",
							String rabbitmqService = "github-rabbitmq", String stubRunnerName = "stubrunner") {
	return """
	if [[ ! -e target/${jarName}.jar || ( -e target/${jarName}.jar && ${redeploy} == "true" ) ]]; then
		${deployAppWithName(stubRunnerName, jarName)}
		${extractMavenProperty("stubrunner.ids")}
		${setEnvVar(stubRunnerName, "stubrunner.ids", '${MAVEN_PROPERTY}')}
		${bindService(eurekaService, stubRunnerName)}
		${bindService(rabbitmqService, stubRunnerName)}
		${restartApp(stubRunnerName)}
		${createServiceWithName(stubRunnerName)}
	else
		echo "The target/${jarName}.jar is missing or redeploy flag was turned off"
	fi
	"""
}

String bindService(String serviceName, String appName) {
	return "cf bind-service ${appName} ${serviceName}"
}

String createServiceWithName(String name) {
	return """
	APPLICATION_DOMAIN=`cf apps | grep ${name} | tr -s ' ' | cut -d' ' -f 6 | cut -d, -f1`
	JSON='{"uri":"http://'\${APPLICATION_DOMAIN}'"}'
	cf create-user-provided-service ${name} -p \${JSON} || echo "Service already created. Proceeding with the script"
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
String downloadJar(String redownloadInfra, String repoWithJars, String groupId, String artifactId, String version) {
	return """
	DESTINATION=target/${artifactId}-${version}.jar
	if [[ ! -e \${DESTINATION} || ( -e \${DESTINATION} && ${redownloadInfra} == "true" ) ]]; then
		mkdir target --parents
		PATH_TO_JAR=${repoWithJars}/${groupId.replace(".", "/")}/${artifactId}/${version}/${artifactId}-${version}.jar
		echo "Downloading \${PATH_TO_JAR} to \${DESTINATION}"
		curl \${PATH_TO_JAR} -o \${DESTINATION}
	fi
	"""
}

String propagatePropertiesForTests(String projectArtifactId, String stubRunnerHost = 'stubrunner') {
	return """
	# retrieve host of the app / stubrunner
	# we have to store them in a file that will be picked as properties
	rm -rf target/test.properties
	${appHost(projectArtifactId)}
	echo "APPLICATION_URL=\${APP_HOST}" >> target/test.properties
	${appHost(stubRunnerHost)}
	echo "STUBRUNNER_URL=\${APP_HOST}" >> target/test.properties
	"""
}

// Function that executes integration tests
String runSmokeTests() {
	return './mvnw clean install -Pintegration -Dapplication.url=${APPLICATION_URL} -Dstubrunner.url=${STUBRUNNER_URL}'
}

String findLatestProdTag() {
	return '''
	LAST_PROD_TAG=$(git for-each-ref --sort=taggerdate --format '%(refname) %(taggerdate)' refs/tags/prod | head -n 1)
	LAST_PROD_TAG=${LAST_PROD_TAG#refs/tags/}
	echo ${LAST_PROD_TAG}
	'''
}

String extractVersionFromProdTag(String tag) {
	return """
	LAST_PROD_VERSION=\${${tag}#prod/}
	echo \${LAST_PROD_VERSION}
	"""
}

//  ======= FUNCTIONS =======
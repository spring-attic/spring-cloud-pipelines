package io.springframework.cloud.compatibility

import io.springframework.cloud.common.SpringCloudJobs
import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.JdkConfig
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class CompatibilityBuildMaker extends CompatibilityTasks implements SpringCloudNotification, TestPublisher,
		JdkConfig, SpringCloudJobs {
	public static final String DEFAULT_BOOT_VERSION = '1.4.0.BUILD-SNAPSHOT'
	public static final String COMPATIBILITY_BUILD_DEFAULT_SUFFIX = 'compatibility-check'

	private final DslFactory dsl
	private final String organization
	private final String suffix

	CompatibilityBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.suffix = COMPATIBILITY_BUILD_DEFAULT_SUFFIX
		this.organization = 'spring-cloud'
	}

	CompatibilityBuildMaker(DslFactory dsl, String suffix) {
		this.dsl = dsl
		this.suffix = suffix
		this.organization = 'spring-cloud'
	}

	CompatibilityBuildMaker(DslFactory dsl, String suffix, String organization) {
		this.dsl = dsl
		this.suffix = suffix
		this.organization = organization
	}

	void build(String projectName, String cronExpr = '') {
		buildWithTests(projectName, cronExpr, true)
	}

	private void buildWithTests(String projectName, String cronExpr, boolean checkTests) {
		String prefixedProjectName = prefixJob(projectName)
		dsl.job("${prefixedProjectName}-${suffix}") {
			concurrentBuild()
			parameters {
				stringParam(SPRING_BOOT_VERSION_VAR, DEFAULT_BOOT_VERSION, 'Which version of Spring Boot should be used for the build')
			}
			triggers {
				if (cronExpr) {
					cron cronExpr
				}
			}
			jdk jdk8()
			scm {
				git {
					remote {
						url "https://github.com/${organization}/$projectName"
						branch 'master'
					}

				}
			}
			steps defaultSteps()
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(cloudRoom())
				}
			}
			if (checkTests) {
				publishers {
					archiveJunit mavenJUnitResults()
				}
			}
		}
	}

	void buildWithoutTests(String projectName, String cronExpr = '') {
		buildWithTests(projectName, cronExpr, false)
	}

}

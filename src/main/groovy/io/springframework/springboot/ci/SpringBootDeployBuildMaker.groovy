package io.springframework.springboot.ci

import io.springframework.common.Cron
import io.springframework.common.JdkConfig
import io.springframework.common.Maven
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import io.springframework.springboot.common.SpringBootJobs
import io.springframework.springboot.common.SpringBootNotification
import javaposse.jobdsl.dsl.DslFactory

import static io.springframework.common.Artifactory.artifactoryMavenBuild
/**
 * @author Marcin Grzejszczak
 */
class SpringBootDeployBuildMaker implements SpringBootNotification, JdkConfig, TestPublisher,
		Cron, SpringBootJobs, Maven {
	private static final List<String> BRANCHES_TO_BUILD = ['master', '1.2.x', '1.3.x']

	private final DslFactory dsl
	final String organization

	SpringBootDeployBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.organization = 'spring-projects'
	}

	SpringBootDeployBuildMaker(DslFactory dsl, String organization) {
		this.dsl = dsl
		this.organization = organization
	}

	void deploy() {
		String project = 'spring-boot'
		BRANCHES_TO_BUILD.each { String branchToBuild ->
			dsl.job("${prefixJob(project)}-$branchToBuild-ci") {
				triggers {
					githubPush()
				}
				jdk jdk8()
				scm {
					git {
						remote {
							url "https://github.com/${organization}/${project}"
							branch branchToBuild
						}
					}
				}
				steps {
					maven {
						mavenInstallation(maven32())
						goals('install -U -P snapshot,prepare,ci -DskipTests')
					}
				}
				configure {
					SlackPlugin.slackNotification(it as Node) {
						room(bootRoom())
					}
					artifactoryMavenBuild(it as Node) {
						mavenVersion(maven32())
						goals('clean install -U -P full -s settings.xml')
						rootPom('spring-boot-full-build/pom.xml')
						mavenOpts('-Xmx2g -XX:MaxPermSize=512m')
					}
//					artifactoryMaven3Configurator(it as Node) {
//						excludePatterns('**/*-tests.jar,**/*-site.jar,**/*spring-boot-sample*,**/*spring-boot-integration-tests*,**/*.effective-pom,**/*-starter-poms.zip')
//					}
				}
				publishers {
					archiveJunit mavenJUnitResults()
					archiveJunit mavenJUnitFailsafeResults()
				}
			}
		}
	}
}

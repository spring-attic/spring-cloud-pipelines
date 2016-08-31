package io.springframework.springio.ci

import io.springframework.common.Cron
import io.springframework.common.JdkConfig
import io.springframework.common.Maven
import io.springframework.common.Pipeline
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import io.springframework.springio.common.AllSpringIoJobs
import io.springframework.springio.common.SpringIoJobs
import io.springframework.springio.common.SpringIoNotification
import javaposse.jobdsl.dsl.DslFactory

import static io.springframework.common.Artifactory.artifactoryMaven3Configurator
import static io.springframework.common.Artifactory.artifactoryMavenBuild

/**
 * @author Marcin Grzejszczak
 */
class SpringInitializrBuildMaker implements SpringIoNotification, JdkConfig, TestPublisher,
		Cron, SpringIoJobs, Maven, Pipeline {
	private final DslFactory dsl
	private final String organization
	private final String branchName

	SpringInitializrBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.organization = 'spring-io'
		this.branchName = 'master'
	}

	SpringInitializrBuildMaker(DslFactory dsl, String organization, String branchName) {
		this.dsl = dsl
		this.organization = organization
		this.branchName = branchName
	}

	void build() {
		dsl.job(jobName()) {
			deliveryPipelineConfiguration('Build', 'Build')
			wrappers {
				defaultDeliveryPipelineVersion()
			}
			triggers {
				githubPush()
			}
			jdk jdk8()
			scm {
				git {
					remote {
						url "https://github.com/${organization}/initializr"
						branch branchName
					}
				}
			}
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(springRoom())
					notifySuccess(true)
				}
				artifactoryMavenBuild(it as Node) {
					mavenVersion(maven33())
					goals('clean install')
				}
				artifactoryMaven3Configurator(it as Node)
			}
			publishers {
				archiveJunit mavenJUnitResults()
				downstreamParameterized {
					trigger(SpringStarterProductionBuildMaker.jobName()) {
						triggerWithNoParameters()
					}
				}
			}
		}
	}

	static String jobName() {
		return "${AllSpringIoJobs.getInitializrName()}-ci"
	}
}

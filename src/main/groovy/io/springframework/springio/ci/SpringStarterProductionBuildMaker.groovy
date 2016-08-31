package io.springframework.springio.ci

import io.springframework.common.*
import io.springframework.springio.common.AllSpringIoJobs
import io.springframework.springio.common.SpringIoJobs
import io.springframework.springio.common.SpringIoNotification
import javaposse.jobdsl.dsl.DslFactory

import static io.springframework.common.CloudFoundryPlugin.pushToCloudFoundry

/**
 * @author Marcin Grzejszczak
 */
class SpringStarterProductionBuildMaker implements SpringIoNotification, JdkConfig, TestPublisher,
		Cron, SpringIoJobs, Pipeline, Maven {
	private final DslFactory dsl
	private final String organization
	private final String branchName

	SpringStarterProductionBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.organization = 'spring-io'
		this.branchName = 'master'
	}

	SpringStarterProductionBuildMaker(DslFactory dsl, String organization, String branchName) {
		this.dsl = dsl
		this.organization = organization
		this.branchName = branchName
	}

	void deploy() {
		dsl.job(jobName()) {
			deliveryPipelineConfiguration('Deploy', 'Push to CF')
			wrappers {
				defaultDeliveryPipelineVersion()
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
			steps {
				maven {
					goals('clean package')
					mavenInstallation(maven30())
					rootPOM('initializr-service/pom.xml')
				}
			}
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(springRoom())
					notifySuccess(true)
				}
				pushToCloudFoundry(it as Node) {
					organization('spring.io')
					cloudSpace('production')
					manifestConfig {
						appName('start')
						appPath('initializr-service/target/initializr-service.jar')
						domain()
					}
				}
			}
		}
	}

	static String jobName() {
		return "${AllSpringIoJobs.getInitializrName()}-production"
	}
}

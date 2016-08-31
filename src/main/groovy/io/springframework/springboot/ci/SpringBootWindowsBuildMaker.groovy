package io.springframework.springboot.ci

import io.springframework.common.*
import io.springframework.springboot.common.SpringBootJobs
import io.springframework.springboot.common.SpringBootNotification
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class SpringBootWindowsBuildMaker implements SpringBootNotification, JdkConfig, TestPublisher,
		Cron, SpringBootJobs, Maven, Label {
	private static final List<String> BRANCHES_TO_BUILD = ['master', '1.2.x', '1.3.x']

	private final DslFactory dsl
	final String organization

	SpringBootWindowsBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.organization = 'spring-projects'
	}

	SpringBootWindowsBuildMaker(DslFactory dsl, String organization) {
		this.dsl = dsl
		this.organization = organization
	}

	void deploy() {
		String project = 'spring-boot'
		BRANCHES_TO_BUILD.each { String branchToBuild ->
			dsl.job("${prefixJob(project)}-$branchToBuild-windows-ci") {
				triggers {
					cron(everyDatAtFullHour(8))
				}
				label(windows())
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
						goals('clean install -U')
					}
				}
				configure {
					SlackPlugin.slackNotification(it as Node) {
						room(bootRoom())
					}
				}
				publishers {
					archiveJunit mavenJUnitResults()
				}
			}
		}
	}
}

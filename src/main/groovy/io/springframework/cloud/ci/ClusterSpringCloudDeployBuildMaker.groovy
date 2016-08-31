package io.springframework.cloud.ci

import io.springframework.cloud.common.ClusterTrait
import io.springframework.cloud.common.SpringCloudJobs
import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.JdkConfig
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class ClusterSpringCloudDeployBuildMaker implements SpringCloudNotification, JdkConfig, TestPublisher,
		ClusterTrait, SpringCloudJobs {
	private final DslFactory dsl

	ClusterSpringCloudDeployBuildMaker(DslFactory dsl) {
		this.dsl = dsl
	}

	void deploy() {
		String project = 'spring-cloud-cluster'
		dsl.job("$project-ci") {
			triggers {
				githubPush()
			}
			parameters {
				stringParam(branchVar(), masterBranch(), 'Which branch should be built')
			}
			jdk jdk8()
			scm {
				git {
					remote {
						url "https://github.com/spring-cloud/${project}"
						branch "\$${branchVar()}"
					}

				}
			}
			steps {
				shell(cleanup())
				shell(buildDocsWithGhPages())
				shell("""
						${preClusterShell()}
						${cleanAndDeploy()} || ${postClusterShell()}
					""")
				shell postClusterShell()
			}
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(cloudRoom())
				}
			}
			publishers {
				archiveJunit mavenJUnitResults()
			}
		}
	}
}

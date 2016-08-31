package io.springframework.cloud.ci

import groovy.transform.PackageScope
import io.springframework.cloud.common.HashicorpTrait
import io.springframework.cloud.common.SpringCloudJobs
import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.Cron
import io.springframework.common.JdkConfig
import io.springframework.common.Maven
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import javaposse.jobdsl.dsl.DslFactory

/**
 * @author Marcin Grzejszczak
 */
@PackageScope
abstract class AbstractHashicorpDeployBuildMaker implements SpringCloudNotification, JdkConfig, TestPublisher, HashicorpTrait,
		Cron, SpringCloudJobs, Maven {
	protected final DslFactory dsl
	protected final String organization
	protected final String project

	AbstractHashicorpDeployBuildMaker(DslFactory dsl, String organization, String project) {
		this.dsl = dsl
		this.organization = organization
		this.project = project
	}

	void deploy(String branchName = 'master') {
		dsl.job("$project-$branchName-ci") {
			triggers {
				cron everyThreeHours()
				githubPush()
			}
			jdk jdk8()
			scm {
				git {
					remote {
						url "https://github.com/${organization}/${project}"
						branch branchName
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			wrappers {
				maskPasswords()
				credentialsBinding {
					usernamePassword(githubRepoUserNameEnvVar(),
							githubRepoPasswordEnvVar(),
							githubUserCredentialId())
				}
				environmentVariables {
					env('BRANCH', branchName)
				}
			}
			steps {
				maven {
					mavenInstallation(maven33())
					goals('--version')
				}
				shell(cleanup())
				shell(buildDocsWithGhPages())
				shell("""\
						${preStep()}
						${cleanAndDeploy()} || ${postStep()}
					""")
				shell postStep()
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

	protected abstract String preStep()
	protected abstract String postStep()
}

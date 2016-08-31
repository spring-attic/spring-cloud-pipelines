package io.springframework.cloud.e2e

import io.springframework.cloud.common.SpringCloudJobs
import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.Cron
import io.springframework.common.JdkConfig
import io.springframework.common.Label
import io.springframework.common.SlackPlugin
import io.springframework.common.TestPublisher
import javaposse.jobdsl.dsl.DslFactory

/**
 * @author Marcin Grzejszczak
 */
class JoshEndToEndBuildMaker implements SpringCloudNotification, TestPublisher,
		JdkConfig, BreweryDefaults, Label, Cron, SpringCloudJobs {

	private final DslFactory dsl
	private final String organization

	JoshEndToEndBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.organization = "joshlong"
	}

	void build(String repoName, String scriptName, String cronExpr, String postBuildScripts) {
		String projectName = 'bootiful-microservices'
		dsl.job("${prefixJob(projectName)}-e2e") {
			triggers {
				cron cronExpr
			}
			jdk jdk8()
			wrappers {
				environmentVariables([
						RETRIES: 35
				])
			}
			scm {
				git {
					remote {
						url "https://github.com/${organization}/$repoName"
						branch 'master'
					}
					extensions {
						wipeOutWorkspace()
					}
				}
			}
			steps {
				shell(cleanup())
				shell("""
						./${scriptName} && echo "Tests passed!" || (echo "Tests failed!! Clearing up" && ./${postBuildScripts} && exit 1)
					""")
				shell("""
					echo "Clearing up after successful tests"
					./${postBuildScripts}
				""")
			}
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(cloudRoom())
				}
			}
		}
	}

}

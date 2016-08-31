package io.springframework.cloud.ci

import io.springframework.cloud.common.SpringCloudJobs
import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.JdkConfig
import io.springframework.common.SlackPlugin
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class DocsAppBuildMaker implements SpringCloudNotification, JdkConfig, SpringCloudJobs {
	private final DslFactory dsl

	DocsAppBuildMaker(DslFactory dsl) {
		this.dsl = dsl
	}

	void buildDocs(String cronExpr) {
		dsl.job('spring-cloud-sleuth-docs-apps-ci') {
			triggers {
				cron cronExpr
			}
			parameters {
				stringParam(branchVar(), masterBranch(), 'Which branch should be built')
			}
			jdk jdk8()
			scm {
				git {
					remote {
						url "https://github.com/spring-cloud-samples/sleuth-documentation-apps"
						branch "\$${branchVar()}"
					}

				}
			}
			steps {
				gradle('clean')
				gradle('build --parallel --refresh-dependencies')
			}

			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(cloudRoom())
				}
			}
		}
	}
}

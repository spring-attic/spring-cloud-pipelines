package io.springframework.cloud.compatibility

import io.springframework.cloud.common.ClusterTrait
import io.springframework.common.TestPublisher
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class ClusterCompatibilityBuildMaker extends CompatibilityTasks implements TestPublisher, ClusterTrait {
	private final DslFactory dsl
	private final String suffix

	ClusterCompatibilityBuildMaker(DslFactory dsl) {
		this.dsl = dsl
		this.suffix = 'compatibility-check'
	}

	ClusterCompatibilityBuildMaker(DslFactory dsl, String suffix) {
		this.dsl = dsl
		this.suffix = suffix
	}

	void build(String cronExpr = '') {
		String projectName = 'spring-cloud-cluster'
		dsl.job("${projectName}-${suffix}") {
			concurrentBuild()
			parameters {
				stringParam(SPRING_BOOT_VERSION_VAR, DEFAULT_BOOT_VERSION, 'Which version of Spring Boot should be used for the build')
			}
			triggers {
				cron cronExpr
			}
			scm {
				git {
					remote {
						url "https://github.com/spring-cloud/$projectName"
						branch 'master'
					}

				}
			}
			steps {
				steps defaultSteps()
				shell postClusterShell()
			}
			publishers {
				archiveJunit mavenJUnitResults()
			}
		}
	}

	@Override
	protected String runTests() {
		return "${preClusterShell()} \n\n ${super.runTests()} || ${postClusterShell()}"
	}
}

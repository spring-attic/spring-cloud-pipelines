package io.springframework.cloud.compatibility

import io.springframework.cloud.common.AllCloudJobs
import io.springframework.cloud.common.SpringCloudJobs
import javaposse.jobdsl.dsl.DslFactory

import static io.springframework.cloud.compatibility.CompatibilityTasks.DEFAULT_BOOT_VERSION
import static io.springframework.cloud.compatibility.CompatibilityTasks.SPRING_BOOT_VERSION_VAR
/**
 * Creates the jobs for the Boot Compatibility verifier
 *
 * @author Marcin Grzejszczak
 */
class BootCompatibilityBuildMaker implements SpringCloudJobs {
	private static final String BOOT_COMPATIBILITY_SUFFIX = 'compatibility-boot-check'

	private final DslFactory dsl

	BootCompatibilityBuildMaker(DslFactory dsl) {
		this.dsl = dsl
	}

	void build() {
		buildAllRelatedJobs()
		dsl.multiJob("spring-cloud-${BOOT_COMPATIBILITY_SUFFIX}") {
			parameters {
				stringParam(SPRING_BOOT_VERSION_VAR, DEFAULT_BOOT_VERSION, 'Which version of Spring Boot should be used for the build')
			}
			steps {
				phase('spring-boot-compatibility-phase') {
					(AllCloudJobs.BOOT_COMPATIBILITY_BUILD_JOBS).each { String projectName ->
						String prefixedProjectName = prefixJob(projectName)
						phaseJob("${prefixedProjectName}-${BOOT_COMPATIBILITY_SUFFIX}".toString()) {
							currentJobParameters()
						}
					}
				}
			}
		}
	}

	void buildAllRelatedJobs() {
		AllCloudJobs.ALL_DEFAULT_JOBS.each { String projectName->
			new CompatibilityBuildMaker(dsl, BOOT_COMPATIBILITY_SUFFIX).build(projectName)
		}
		AllCloudJobs.JOBS_WITHOUT_TESTS.each {
			new CompatibilityBuildMaker(dsl, BOOT_COMPATIBILITY_SUFFIX).buildWithoutTests(it)
		}
		new ConsulCompatibilityBuildMaker(dsl, BOOT_COMPATIBILITY_SUFFIX).build()
		new ClusterCompatibilityBuildMaker(dsl, BOOT_COMPATIBILITY_SUFFIX).build()
		new CompatibilityBuildMaker(dsl, BOOT_COMPATIBILITY_SUFFIX, 'spring-cloud-samples').build('tests')
	}
}

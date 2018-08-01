package org.springframework.cloud.pipelines.spinnaker

import groovy.io.FileType
import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.dsl.GeneratedItems
import javaposse.jobdsl.dsl.JobParent
import javaposse.jobdsl.dsl.MemoryJobManagement
import javaposse.jobdsl.dsl.ScriptRequest
import spock.lang.Specification
import spock.lang.Unroll

import org.springframework.cloud.pipelines.util.JobCreator
import org.springframework.cloud.pipelines.util.XmlComparator

/**
 * Tests that all Spinnaker dsl scripts work fine.
 */
class StepsSpec extends Specification  implements JobCreator, XmlComparator {

	JobParent jobParent = createJobParent()
	MemoryJobManagement jm = jobParent.jm

	@Override
	String folderName() {
		return "spinnaker-jobs"
	}

	def 'should build all jobs'() {
		given:
			jm.parameters << [
				SCRIPTS_DIR    : 'foo',
				JENKINSFILE_DIR: 'foo',
				TEST_MODE_DESCRIPTOR: '',
				PAAS_TEST_SPACE_PREFIX: 'sc-pipelines-test',
				SPINNAKER_TEST_HOSTNAME: 'foo.com',
				SPINNAKER_STAGE_HOSTNAME: 'foo.com',
				SPINNAKER_PROD_HOSTNAME: 'foo.com',
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "test-env-rollback-test", "stage-env-test", 'prod-env-remove-tag'].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			jobs - scripts.jobs.collect { it.jobName } == []
		and:
			jm.savedConfigs.find { it.key == "spinnaker-foo-pipeline-build" }.with {
				assert it.value.contains("build_api_compatibility_check.sh")
				assert it.value.contains("build_and_upload.sh")
				return it
			}
		and:
			storeJobsAndViews(jm)
			assertJobsAndViews(jm)
	}

	def 'should not run api compatibility when descriptor disables it'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			jm.parameters << [
				SCRIPTS_DIR    : 'foo',
				JENKINSFILE_DIR: 'foo',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  api_compatibility_step: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "test-env-rollback-test", "stage-env-test"].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			jm.savedConfigs.find { it.key == "spinnaker-foo-pipeline-build" }.with {
				assert !it.value.contains("build_api_compatibility_check.sh")
				assert it.value.contains("build_and_upload.sh")
				return it
			}
	}

	def 'should not run api compatibility if that option is checked'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			jm.parameters << [
				SCRIPTS_DIR                    : 'foo',
				JENKINSFILE_DIR                : 'foo',
				API_COMPATIBILITY_STEP_REQUIRED: 'false',
				TEST_MODE_DESCRIPTOR: ''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "test-env-rollback-test", "stage-env-test"].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			jm.savedConfigs.find { it.key == "spinnaker-foo-pipeline-build" }.with {
				assert !it.value.contains("build_api_compatibility_check.sh")
				assert it.value.contains("build_and_upload.sh")
				return it
			}
	}

	def 'should not include test jobs when that option was unchecked'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			jm.parameters << [
				SCRIPTS_DIR    : 'foo',
				JENKINSFILE_DIR: 'foo',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  test_step: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "stage-env-test"].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("test-env") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
	}

	def 'should not include stage jobs when that option was unchecked'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			jm.parameters << [
				SCRIPTS_DIR         : 'foo',
				JENKINSFILE_DIR     : 'foo',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  stage_step: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-rollback-test", "test-env-test"].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("stage") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
	}

	def 'should not include test rollback jobs when that option was unchecked'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			jm.parameters << [
				SCRIPTS_DIR         : 'foo',
				JENKINSFILE_DIR     : 'foo',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  rollback_step: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_spinnaker_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "stage-env-test"].collect {
				"spinnaker-foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("test-env-rollback-test") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
	}

	static List<File> getJobFiles() {
		List<File> files = []
		new File('jobs').eachFileRecurse(FileType.FILES) {
			files << it
		}
		return files
	}

}


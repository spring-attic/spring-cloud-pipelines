package org.springframework.cloud.pipelines.default_pipeline

import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.dsl.GeneratedItems
import javaposse.jobdsl.dsl.JobParent
import javaposse.jobdsl.dsl.MemoryJobManagement
import javaposse.jobdsl.dsl.ScriptRequest
import spock.lang.Specification

import org.springframework.cloud.pipelines.common.TestJobCustomizer
import org.springframework.cloud.pipelines.util.JobCreator
import org.springframework.cloud.pipelines.util.XmlComparator

/**
 * @author Marcin Grzejszczak
 */
class DefaultPipelineBuilderSpec extends Specification implements JobCreator, XmlComparator {

	JobParent jobParent = createJobParent()
	MemoryJobManagement jm = jobParent.jm

	def setup() {
		TestJobCustomizer.EXECUTED_ALL = false
		TestJobCustomizer.EXECUTED_BUILD = false
		TestJobCustomizer.EXECUTED_TEST = false
		TestJobCustomizer.EXECUTED_STAGE = false
		TestJobCustomizer.EXECUTED_PROD = false
	}

	@Override
	String folderName() {
		return "default-pipeline"
	}

	def 'should create the whole pipeline'() {
		given:
			jm.parameters << [
				SCRIPTS_DIR    : 'foo',
				JENKINSFILE_DIR: 'foo',
				TEST_MODE_DESCRIPTOR: '',
				SPINNAKER_TEST_HOSTNAME: 'apps.foo.com',
				SPINNAKER_STAGE_HOSTNAME: 'apps.foo.com',
				SPINNAKER_PROD_HOSTNAME: 'apps.foo.com',
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			storeJobsAndViews(jm)
			assertJobsAndViews(jm)
		and:
			TestJobCustomizer.EXECUTED_ALL
			TestJobCustomizer.EXECUTED_BUILD
			TestJobCustomizer.EXECUTED_TEST
			TestJobCustomizer.EXECUTED_STAGE
			TestJobCustomizer.EXECUTED_PROD
	}

	def 'should not run api compatibility when descriptor disables it'() {
		given:
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
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "test-env-rollback-test", "stage-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			jm.savedConfigs.find { it.key == "foo-pipeline-build" }.with {
				assert !it.value.contains("build_api_compatibility_check.sh")
				assert it.value.contains("build_and_upload.sh")
				return it
			}
	}

	def 'should not run api compatibility if that option is checked'() {
		given:
			jm.parameters << [
				SCRIPTS_DIR                    : 'foo',
				JENKINSFILE_DIR                : 'foo',
				API_COMPATIBILITY_STEP_REQUIRED: 'false',
				TEST_MODE_DESCRIPTOR: ''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "test-env-rollback-test", "stage-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			jm.savedConfigs.find { it.key == "foo-pipeline-build" }.with {
				assert !it.value.contains("build_api_compatibility_check.sh")
				assert it.value.contains("build_and_upload.sh")
				return it
			}
	}

	def 'should automatically run stage deploy if test jobs where not included'() {
		given:
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
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "stage-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("test-env") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			String build = jm.savedConfigs.find { it.key == "foo-pipeline-build" }.value
			build.contains("<projects>foo-pipeline-stage-env-deploy</projects>")
	}

	def 'should manually run stage deploy if test jobs where not included and auto stage is off'() {
		given:
			jm.parameters << [
				SCRIPTS_DIR    : 'foo',
				JENKINSFILE_DIR: 'foo',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  api_compatibility_step: false
  test_step: false
  auto_stage: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "stage-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("test-env") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			String build = jm.savedConfigs.find { it.key == "foo-pipeline-build" }.value
			build.contains("<downstreamProjectNames>foo-pipeline-stage-env-deploy</downstreamProjectNames>")
	}

	def 'should not include stage jobs when that option was unchecked'() {
		given:
			jm.parameters << [
				SCRIPTS_DIR         : 'foo',
				JENKINSFILE_DIR     : 'foo',
				AUTO_DEPLOY_TO_PROD : 'false',
				TEST_MODE_DESCRIPTOR: '''
pipeline:
  stage_step: false
'''
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-rollback-test", "test-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("stage") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }

		and:
			String build = jm.savedConfigs.find { it.key == "foo-pipeline-test-env-rollback-test" }.value
			build.contains("<downstreamProjectNames>foo-pipeline-prod-env-deploy</downstreamProjectNames>")
	}

	def 'should not include test rollback jobs when that option was unchecked'() {
		given:
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
				new File("jobs/jenkins_pipeline_crawler_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			def jobs = ['build', "test-env-test", "stage-env-test"].collect {
				"foo-pipeline-${it}".toString()
			}
			scripts.jobs.every { !it.jobName.contains("test-env-rollback-test") }
			scripts.jobs.collect { it.jobName }.any { jobs.contains(it) }
		and:
			String build = jm.savedConfigs.find { it.key == "foo-pipeline-test-env-test" }.value
			build.contains("<projects>foo-pipeline-stage-env-deploy</projects>")
	}
}

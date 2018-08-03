package org.springframework.cloud.pipelines

import groovy.io.FileType
import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.dsl.GeneratedItems
import javaposse.jobdsl.dsl.MemoryJobManagement
import javaposse.jobdsl.dsl.ScriptRequest
import spock.lang.Specification
import spock.lang.Unroll
/**
 * Tests that all dsl scripts in the jobs directory will compile.
 */
class SingleScriptPipelineSpec extends Specification {

	//remove::start[CF]
	def 'should create seed job for CF'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("seed/jenkins_pipeline.groovy").text)])

		then:
		noExceptionThrown()

		and:
		scripts.jobs.collect { it.jobName }.contains("jenkins-pipeline-cf-seed")
	}
	//remove::end[CF]

	//remove::start[K8S]
	def 'should create seed job for K8s'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
			new File("seed/jenkins_pipeline.groovy").text)])

		then:
		noExceptionThrown()

		and:
		scripts.jobs.collect { it.jobName }.contains("jenkins-pipeline-k8s-seed")
	}
	//remove::end[K8S]

	def 'should parse REPOS with no special entries'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'http://foo/bar'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "bar-pipeline-build" }.with {
				assert it.value.contains("<url>http://foo/bar</url>")
				assert it.value.contains("<name>master</name>")
				return it
			}
	}

	def 'should parse REPOS with no special entries for ssh based authentication'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'git@github.com:marcingrzejszczak/github-analytics-kubernetes.git'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "github-analytics-kubernetes-pipeline-build" }.with {
				assert it.value.contains("<url>git@github.com:marcingrzejszczak/github-analytics-kubernetes.git")
				assert it.value.contains("<name>master</name>")
				return it
			}
	}

	def 'should parse REPOS with custom project name only'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'http://foo/bar$custom'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "custom-pipeline-build" }.with {
				assert it.value.contains("<url>http://foo/bar</url>")
				assert it.value.contains("<name>master</name>")
				return it
			}
	}

	def 'should parse REPOS with custom branch name only'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'http://foo/bar#custom'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "bar-pipeline-build" }.with {
				assert it.value.contains("<url>http://foo/bar</url>")
				assert it.value.contains("<name>custom</name>")
				return it
			}
	}

	def 'should parse REPOS with custom branch name and project name'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'http://foo/bar#customBranch$customName'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "customName-pipeline-build" }.with {
				assert it.value.contains("<url>http://foo/bar</url>")
				assert it.value.contains("<name>customBranch</name>")
				return it
			}
	}

	def 'should parse REPOS with custom project name and branch name'() {
		given:
			MemoryJobManagement jm = new MemoryJobManagement()
			defaultStubbing(jm)
			jm.parameters << [
				SCRIPTS_DIR: 'foo',
				JENKINSFILE_DIR: 'foo',
				REPOS: 'http://foo/bar$customName#customBranch'
			]
			DslScriptLoader loader = new DslScriptLoader(jm)

		when:
			GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			noExceptionThrown()

		and:
			jm.savedConfigs.find { it.key == "customName-pipeline-build" }.with {
				assert it.value.contains("<url>http://foo/bar</url>")
				assert it.value.contains("<name>customBranch</name>")
				return it
			}
	}

	def 'should not include stage jobs when that option was unchecked'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		defaultStubbing(jm)
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			DEPLOY_TO_STAGE_STEP_REQUIRED: 'false'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		scripts.jobs.every { !it.jobName.contains("stage") }
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-test-env-rollback-test" }.with {
			assert it.value.contains("<downstreamProjectNames>github-webhook-pipeline-prod-env-deploy</downstreamProjectNames>")
			return it
		}
	}

	def 'should automatically run api compatibility by default'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-build" }.with {
			assert it.value.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert it.value.contains("build_api_compatibility_check.sh")
			assert it.value.contains("<projects>github-webhook-pipeline-test-env-deploy</projects>")
			assert !it.value.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			return it
		}
	}

	def 'should not run api compatibility if that option is checked'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			API_COMPATIBILITY_STEP_REQUIRED: 'false'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-build" }.with {
			assert it.value.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert !it.value.contains("build_api_compatibility_check.sh")
			assert it.value.contains("<projects>github-webhook-pipeline-test-env-deploy</projects>")
			assert !it.value.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			return it
		}
		!scripts.jobs.find { it.jobName == "github-webhook-pipeline-build-api-check" }
	}

	def 'should automatically deploy to stage if that option is checked'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			AUTO_DEPLOY_TO_STAGE: 'true'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-test-env-rollback-test" }.with {
			assert it.value.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert it.value.contains("<projects>github-webhook-pipeline-stage-env-deploy</projects>")
			assert !it.value.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			return it
		}
	}

	def 'should manually deploy to stage by default'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-test-env-rollback-test" }.with {
			assert !it.value.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert !it.value.contains("<projects>github-webhook-pipeline-stage-env-deploy</projects>")
			assert it.value.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			assert it.value.contains("<downstreamProjectNames>github-webhook-pipeline-stage-env-deploy</downstreamProjectNames>")
			return it
		}
	}

	def 'should automatically deploy to prod if that option is checked'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			AUTO_DEPLOY_TO_PROD: 'true'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-stage-env-test" }.with {
			assert it.value.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert it.value.contains("<projects>github-webhook-pipeline-prod-env-deploy</projects>")
			assert !it.value.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			return it
		}
	}

	def 'should manually deploy to prod by default'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-stage-env-test" }.value.with {
			assert !it.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert !it.contains("<projects>github-webhook-pipeline-prod-env-deploy</projects>")
			assert it.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			assert it.contains("<downstreamProjectNames>github-webhook-pipeline-prod-env-deploy</downstreamProjectNames>")
			return it
		}
	}

	def 'should manually complete switch over and rollback to prod by default'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
				new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.find { it.key == "github-webhook-pipeline-prod-env-deploy" }.value.with {
			assert !it.contains("hudson.plugins.parameterizedtrigger.BuildTrigger")
			assert !it.contains("<projects>github-webhook-pipeline-prod-env-complete,github-webhook-pipeline-prod-env-rollback</projects>")
			assert it.contains("au.com.centrumsystems.hudson.plugin.buildpipeline.trigger.BuildPipelineTrigger")
			assert it.contains("<downstreamProjectNames>github-webhook-pipeline-prod-env-complete,github-webhook-pipeline-prod-env-rollback</downstreamProjectNames>")
			return it
		}
	}

	def 'should use Git SSH key if specified in all jobs'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			GIT_USE_SSH_KEY: 'true',
			GIT_SSH_CREDENTIAL_ID: 'testSshKeyId'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		noExceptionThrown()

		and:
		jm.savedConfigs.each {
			def jobConfig = new XmlParser().parse(new StringReader(it.value))
			def jobName = it.key
			assert jobConfig.scm.size() == 1, [ "No SCM configuration found for job $jobName" ]
			assert jobConfig.scm[0].@class.contains('GitSCM'), [ "Expected Git SCM configuration in job $jobName" ]
			with(jobConfig.scm[0]) {
				def credentialsId = userRemoteConfigs.'hudson.plugins.git.UserRemoteConfig'.credentialsId
				assert credentialsId, [ "No Git SCM credentials found for job $jobName" ]
				assert credentialsId.text() == 'testSshKeyId', [ "Wrong Git SCM credentials in job $jobName"]
			}
		}
	}

	def 'should treat non-tarball and non-git URL with pipelines functions as git'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			TOOLS_REPOSITORY: 'https://akjsad.com/foo/bar'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
			assertScriptForScriptsDownloading(jm, 'rm -rf .git/tools && git clone -b master --single-branch https://akjsad.com/foo/bar .git/tools')
	}

	def 'should curl for tarball with pipelines functions by default'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		assertScriptForScriptsDownloading(jm, 'curl -Lk "https://github.com/spring-cloud/spring-cloud-pipelines/raw/master/dist/spring-cloud-pipelines.tar.gz" -o pipelines.tar.gz && tar xf pipelines.tar.gz --strip-components 1')
	}

	def 'should curl for tar ball with pipelines functions if archives ends with .tar.gz'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			TOOLS_REPOSITORY: 'https://foo.com/bar.tar.gz'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		assertScriptForScriptsDownloading(jm, 'curl -Lk "https://foo.com/bar.tar.gz" -o pipelines.tar.gz && tar xf pipelines.tar.gz --strip-components 1')
	}

	def 'should clone git repo with pipelines functions if url ends with .git'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			TOOLS_REPOSITORY: 'https://foo.com/bar.git',
			TOOLS_BRANCH: 'baz'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		assertScriptForScriptsDownloading(jm, 'rm -rf .git/tools && git clone -b baz --single-branch https://foo.com/bar.git .git/tools')
	}

	def 'should clone git repo with pipelines functions with default master branch if url ends with .git'() {
		given:
		MemoryJobManagement jm = new MemoryJobManagement()
		jm.parameters << [
			SCRIPTS_DIR: 'foo',
			JENKINSFILE_DIR: 'foo',
			TOOLS_REPOSITORY: 'https://foo.com/bar.git'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		loader.runScripts([new ScriptRequest(
			new File("jobs/jenkins_pipeline_sample.groovy").text)])

		then:
		assertScriptForScriptsDownloading(jm, 'rm -rf .git/tools && git clone -b master --single-branch https://foo.com/bar.git .git/tools')
	}

	static void assertScriptForScriptsDownloading(MemoryJobManagement jm, String command) {
		assert !jm.savedConfigs.isEmpty()
		jm.savedConfigs.each {
			def jobConfig = new XmlParser().parse(new StringReader(it.value))
			assert jobConfig.builders.size() == 1, [ "One shell builder" ]
			assert jobConfig.builders[0].find { def task ->
				task.command.text().contains(command)
			}
		}
	}

	static List<File> getJobFiles() {
		List<File> files = []
		new File('jobs').eachFileRecurse(FileType.FILES) {
			files << it
		}
		return files
	}

	private void defaultStubbing(MemoryJobManagement jm) {
		jm.availableFiles['foo/Jenkinsfile-sample'] = new File('declarative-pipeline/Jenkinsfile-sample').text
		jm.availableFiles['foo/pipeline.sh'] = JobScriptsSpec.getResource('/pipeline.sh').text
		jm.availableFiles['foo/build_and_upload.sh'] = JobScriptsSpec.getResource('/build_and_upload.sh').text
		jm.availableFiles['foo/build_api_compatibility_check.sh'] = JobScriptsSpec.getResource('/build_api_compatibility_check.sh').text
		jm.availableFiles['foo/test_deploy.sh'] = JobScriptsSpec.getResource('/test_deploy.sh').text
		jm.availableFiles['foo/test_smoke.sh'] = JobScriptsSpec.getResource('/test_smoke.sh').text
		jm.availableFiles['foo/test_rollback_deploy.sh'] = JobScriptsSpec.getResource('/test_rollback_deploy.sh').text
		jm.availableFiles['foo/test_rollback_smoke.sh'] = JobScriptsSpec.getResource('/test_rollback_smoke.sh').text
		jm.availableFiles['foo/stage_deploy.sh'] = JobScriptsSpec.getResource('/stage_deploy.sh').text
		jm.availableFiles['foo/stage_e2e.sh'] = JobScriptsSpec.getResource('/stage_e2e.sh').text
		jm.availableFiles['foo/prod_deploy.sh'] = JobScriptsSpec.getResource('/prod_deploy.sh').text
		jm.availableFiles['foo/prod_complete.sh'] = JobScriptsSpec.getResource('/prod_complete.sh').text
	}

}


package io.springframework.cloud

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
class JobScriptsSpec extends Specification {

	@Unroll
	def 'test script #file.name'() {
		given:

		MemoryJobManagement jm = new MemoryJobManagement()
		jm.availableFiles['foo/pipeline.sh'] = JobScriptsSpec.getResource('/pipeline.sh').text
		jm.availableFiles['foo/build_and_upload.sh'] = JobScriptsSpec.getResource('/build_and_upload.sh').text
		jm.availableFiles['foo/test_deploy.sh'] = JobScriptsSpec.getResource('/test_deploy.sh').text
		jm.availableFiles['foo/test_smoke.sh'] = JobScriptsSpec.getResource('/test_smoke.sh').text
		jm.availableFiles['foo/test_rollback_deploy.sh'] = JobScriptsSpec.getResource('/test_rollback_deploy.sh').text
		jm.availableFiles['foo/test_rollback_smoke.sh'] = JobScriptsSpec.getResource('/test_rollback_smoke.sh').text
		jm.availableFiles['foo/stage_deploy.sh'] = JobScriptsSpec.getResource('/stage_deploy.sh').text
		jm.availableFiles['foo/stage_e2e.sh'] = JobScriptsSpec.getResource('/stage_e2e.sh').text
		jm.availableFiles['foo/prod_deploy.sh'] = JobScriptsSpec.getResource('/prod_deploy.sh').text
		jm.availableFiles['foo/prod_complete.sh'] = JobScriptsSpec.getResource('/prod_complete.sh').text
		jm.parameters << [
				SCRIPTS_DIR: 'foo'
		]
		DslScriptLoader loader = new DslScriptLoader(jm)

		when:
		GeneratedItems scripts = loader.runScripts([new ScriptRequest(file.text)])

		then:
		noExceptionThrown()

		and:
		if (file.name.endsWith('jenkins_pipeline_sample.groovy')) {
			List<String> jobNames = scripts.jobs.collect { it.jobName }
			assert jobNames.find { it == "github-analytics-pipeline-build" }
			assert jobNames.find { it == "github-webhook-pipeline-build" }
		}

		where:
		file << jobFiles
	}

	static List<File> getJobFiles() {
		List<File> files = []
		new File('jobs').eachFileRecurse(FileType.FILES) {
			files << it
		}
		return files
	}

}


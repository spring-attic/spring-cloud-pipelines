package org.springframework.cloud.pipelines

import groovy.io.FileType
import org.gradle.api.Project
import org.gradle.api.logging.Logger
import org.gradle.testfixtures.ProjectBuilder
import org.junit.Rule
import spock.lang.Specification

import org.springframework.boot.test.rule.OutputCapture

import java.util.regex.Matcher

/**
 * @author Marcin Grzejszczak
 */
class ProjectCustomizerSpec extends Specification {

	@Rule OutputCapture capture = new OutputCapture()

	File testResources = new File("src/test/resources/project_customizer/")
	File outputResources = new File("build/resources/test/project_customizer/")
	Project project = ProjectBuilder
		.builder()
		.withProjectDir(outputResources)
		.build()

	def setup() {
		outputResources.deleteDir()
		new AntBuilder().copy( todir: outputResources.absolutePath ) {
			fileset( dir: testResources.absolutePath )
		}
	}

	def "should not remove anything when BOTH picked"() {
		given:
			InputReader reader = Stub(InputReader)
			reader.println(_) >> { println it }
			Logger logger = Stub(Logger)
			logger.info(_) >> { String text -> println text }
			ProjectCustomizer customizer = new ProjectCustomizer(project, reader)
		when:
			customizer.customize()
		then:
			String logs = capture.toString()
			logs.contains("Doing nothing since you've picked the ALL PaaS option")
			logs.contains("Doing nothing since you've picked the ALL CI tools option")
			!logs.contains("Removing files")
			!logs.contains("Removing lines")
	}

	def "should leave anything related to Jenkins and K8S"() {
		given:
			InputReader reader = Stub(InputReader)
			reader.readLine() >> "k8s" >> "Jenkins"
			Logger logger = Stub(Logger)
			logger.info(_) >> { String text -> println text }
			ProjectCustomizer customizer = new ProjectCustomizer(project, reader)
		when:
			customizer.customize()
		then:
			String logs = capture.toString()
			//
			!logs.contains(filePath("buildSrc/foo.bash"))
			// we want to remove only Concourse stuff
			!logs.contains(filePath("/jenkins,"))
			logs.contains(filePath("images/concourse"))
			logs.contains(filePath("CONCOURSE.adoc"))
			logs.contains(filePath("CF_DEMO.adoc"))
			logs.contains(filePath("CF_JENKINS"))
			logs.contains(filePath("tools/cf-helper"))
			logs.contains(filePath("bash/pipeline-cf"))
			logs.contains("Removing lines")
			logs.contains("Removing files")
		and:
			outputResources.eachFileRecurse(FileType.FILES) {
				String text = it.text.toLowerCase()
				assert !text.contains("remove::start[concourse]")
				assert !text.contains("remove::start[cf]")
			}
	}

	def "should leave anything related to Concourse and CF"() {
		given:
			InputReader reader = Stub(InputReader)
			reader.readLine() >> "cf" >> "Concourse"
			Logger logger = Stub(Logger)
			logger.info(_) >> { String text -> println text }
			ProjectCustomizer customizer = new ProjectCustomizer(project, reader)
		when:
			customizer.customize()
		then:
			String logs = capture.toString()
			//
			!logs.contains(filePath("buildSrc/foo.bash"))
			// we want to remove only Concourse stuff
			!logs.contains(filePath("/concourse,"))
			logs.contains(filePath("images/jenkins"))
			logs.contains(filePath("JENKINS.adoc"))
			logs.contains(filePath("K8S_DEMO.adoc"))
			logs.contains(filePath("K8S_JENKINS"))
			logs.contains(filePath("tools/k8s-helper"))
			logs.contains(filePath("bash/pipeline-k8s"))
			logs.contains("Removing lines")
			logs.contains("Removing files")
		and:
			outputResources.eachFileRecurse(FileType.FILES) {
				String text = it.text.toLowerCase()
				assert !text.contains("remove::start[jenkins]")
				assert !text.contains("remove::start[k8s]")
			}
	}

	String filePath(String canonicalPath) {
		return canonicalPath.replaceAll("/", Matcher.quoteReplacement(File.separator))
	}

}

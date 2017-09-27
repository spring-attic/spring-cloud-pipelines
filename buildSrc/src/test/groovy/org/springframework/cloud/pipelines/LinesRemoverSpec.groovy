package org.springframework.cloud.pipelines

import org.gradle.api.Project
import org.gradle.testfixtures.ProjectBuilder
import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class LinesRemoverSpec extends Specification {

	File testResources = new File("src/test/resources/lines_remover")
	File outputResources = new File("build/resources/test/lines_remover")
	Project project = ProjectBuilder
		.builder()
		.withProjectDir(outputResources.parentFile)
		.build()
	LinesRemover remover = new LinesRemover(new SystemOutReader(), project)

	def setup() {
		outputResources.mkdirs()
		new File(outputResources, "simple_file.txt").text = new File(testResources, "simple_file.txt").text
	}

	def "should not remove entries from a file that contains start and end tag"() {
		when:
			remover.modifyFiles(outputResources.absolutePath, new Options(), ["**/*.txt"])
		then:
			new File(outputResources, "simple_file.txt").text == """tag::
end::
don't remove 1
// remove::start[]
remove
// remove::end[]
// remove::start[CF]
remove CF
// remove::end[CF]
// remove::start[K8S]
remove K8S
// remove::end[K8S]
// remove::start[Jenkins]
remove Jenkins
// remove::end[Jenkins]
// remove::start[Concourse]
remove Concourse
// remove::end[Concourse]
don't remove 2
// remove::start[return]
return some value
// remove::end[return]
//remove::start[return]
return some value 2
//remove::end[return]
"""
	}

	def "should remove entries from a file that contains start and end tag when K8S + Jenkins options are passed"() {
		when:
			remover.modifyFiles(outputResources.absolutePath, Options.builder()
				.paasType(Options.PaasType.K8S)
				.ciTool(Options.CiTool.JENKINS)
				.build(), ["**/*.txt"])
		then:
			new File(outputResources, "simple_file.txt").text == """don't remove 1
remove K8S
remove Jenkins
don't remove 2
return null;
return null;
"""
	}

	def "should remove entries from a file that contains start and end tag when CF + Concourse options are passed"() {
		when:
			remover.modifyFiles(outputResources.absolutePath, Options.builder()
				.paasType(Options.PaasType.CF)
				.ciTool(Options.CiTool.CONCOURSE)
				.build(), ["**/*.txt"])
		then:
			new File(outputResources, "simple_file.txt").text == """don't remove 1
remove CF
remove Concourse
don't remove 2
return null;
return null;
"""
	}

	def "should not modify the file if it's missing the start tag"() {
		given:
			String initialText = new File(outputResources, "file_without_tags.txt").text
		when:
			remover.modifyFiles(outputResources.absolutePath, new Options(), ["**/*.txt"])
		then:
			new File(outputResources, "file_without_tags.txt").text == initialText
	}
}

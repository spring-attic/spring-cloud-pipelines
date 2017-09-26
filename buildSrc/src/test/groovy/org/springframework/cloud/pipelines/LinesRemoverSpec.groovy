package org.springframework.cloud.pipelines

import org.gradle.api.Project
import org.gradle.testfixtures.ProjectBuilder
import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class LinesRemoverSpec extends Specification {

	File resources = new File("build/resources/test/lines_remover")
	Project project = ProjectBuilder
		.builder()
		.withProjectDir(resources.parentFile)
		.build();
	LinesRemover remover = new LinesRemover(project)

	def "should remove entries from a file that contains start and end tag"() {
		when:
			remover.modifyFiles(resources.absolutePath, ["**/*.txt"])
		then:
			new File(resources, "simple_file.txt").text == """don't remove 1
don't remove 2
return null;
return null;
"""
	}
}

package org.springframework.cloud.pipelines

import org.gradle.api.Project
import org.gradle.testfixtures.ProjectBuilder
import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class FileRemoverSpec extends Specification {

	File resources = new File("build/resources/test/folder_to_remove")
	Project project = ProjectBuilder
		.builder()
		.withProjectDir(resources.parentFile)
		.build()
	FileRemover remover = new FileRemover(new SystemOutReader(), project)

	def "should remove the whole directory"() {
		when:
			remover.deleteFiles([resources.absolutePath])
		then:
			!resources.exists()
	}

	def "should remove a single file"() {
		given:
			File singleFile = new File(resources, "remove.me")
		when:
			remover.deleteFiles([singleFile.absolutePath])
		then:
			!singleFile.exists()
	}

}

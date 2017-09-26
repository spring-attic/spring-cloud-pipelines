package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import org.gradle.api.Project

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class ProjectCustomizer {
	private final OptionsReader optionsReader
	private final Project project
	private final FileRemover fileRemover
	private final LinesRemover linesRemover

	ProjectCustomizer(Project project, OptionsReader optionsReader) {
		this.optionsReader = optionsReader
		this.project = project
		this.fileRemover = new FileRemover(project)
		this.linesRemover = new LinesRemover(project)
	}

	void customize() {
		Options options = this.optionsReader.read()
		switch(options.ciTool) {
			case Options.CiTool.JENKINS:
				break
			case Options.CiTool.CONCOURSE:
				break
			case Options.CiTool.BOTH:
				project.logger.info("Doing nothing since you've picked the BOTH option")
		}
		switch (options.paasType) {
			case Options.PaasType.CF:
				break
			case Options.PaasType.K8S:
				break
			case Options.PaasType.BOTH:
				project.logger.info("Doing nothing since you've picked the BOTH option")
		}
	}
}

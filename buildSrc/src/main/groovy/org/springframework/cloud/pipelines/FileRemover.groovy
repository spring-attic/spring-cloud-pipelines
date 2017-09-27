package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import org.gradle.api.Project
import org.gradle.api.file.FileTree

@PackageScope
@CompileStatic
class FileRemover {

	private final Project project

	FileRemover(Project project) {
		this.project = project
	}

	void deleteFiles(List<String> paths) {
		if (paths.empty) {
			return
		}
		project.logger.info("Removing files ${paths}")
		project.delete(paths)
	}
}

package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import org.gradle.api.Project
import org.gradle.api.file.FileTree

@PackageScope
@CompileStatic
class FileRemover {

	private final Project project
	private final InputReader inputReader

	FileRemover(InputReader inputReader, Project project) {
		this.project = project
		this.inputReader = inputReader
	}

	void deleteFiles(List<String> paths) {
		if (paths.empty) {
			return
		}
		inputReader.println("Removing files ${paths}")
		project.delete(paths)
	}
}

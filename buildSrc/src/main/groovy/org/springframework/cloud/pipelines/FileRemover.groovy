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

	void deleteFiles(String dirName) {
		project.delete(dirName)
	}
}

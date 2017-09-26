package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import org.gradle.api.Project
import org.gradle.api.file.FileTree

@PackageScope
@CompileStatic
class LinesRemover {

	private final Project project

	LinesRemover(Project project) {
		this.project = project
	}

	void modifyFiles(String dirName, List<String> includes = ['**/*.java',
															  '**/*.groovy',
															  '**/*.adoc',
															  '**/*.bats',
															  '**/*.bash',
															  '**/*.sh',
															  '**/Jenkinsfile-sample',
															  '**/Dockerfile',
															  '**/*.txt',
															  '**/*.xml',
															  '**/*.gradle',
															  '**/*.yml',
															  '**/*.properties']) {
		FileTree tree = project.fileTree(dir: dirName, include: includes)
		tree.each { File file ->
			if (file.absolutePath == new File(project.rootDir, "build.gradle").absolutePath) {
				return
			}
			String text = file.text
			if (!text.contains("remove::start")) {
				return
			}
			StringBuilder newString = new StringBuilder()
			boolean remove = false
			text.eachLine { String line ->
				if(["tag::", "end::"].any { line.contains(it) }) {
					return
				}
				// reached the end of the removal line
				if (line.contains("remove::end[]")) {
					remove = false
				} else if (line.contains("remove::end[return]")) {
					// removal with providing of a return value
					newString.append(line
						.replace("//remove::end[return]", "return null;")
						.replace("// remove::end[return]", "return null;")
					).append("\n")
					remove = false
					return
				}
				if (!remove) {
					if (line.contains("remove::start")) {
						remove = true
					} else if (!line.contains("remove::end")) {
						newString.append(line).append("\n")
					}
				}
				return
			}
			file.text = newString.toString()
		}
	}
}

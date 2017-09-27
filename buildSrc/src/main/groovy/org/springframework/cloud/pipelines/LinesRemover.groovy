package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.PackageScope
import org.gradle.api.Project
import org.gradle.api.file.FileTree

@PackageScope
@CompileStatic
class LinesRemover {

	private final Project project
	private final InputReader inputReader
	private final List<String> ignored

	LinesRemover(InputReader inputReader, Project project) {
		this.project = project
		this.inputReader = inputReader
		this.ignored = [
		        '**/buildSrc/**'
		]
	}

	void modifyFiles(String dirName, Options options, List<String> includes = ['**/*.java',
															  '**/*.groovy',
															  '**/*.adoc',
															  '**/*.bats',
															  '**/*.bash',
															  '**/*.sh',
															  '**/Jenkinsfile-sample',
															  '**/Dockerfile',
															  '**/*.xml',
															  '**/*.gradle',
															  '**/*.yml',
															  '**/*.properties']) {
		if (options.ciTool == Options.CiTool.BOTH && options.paasType == Options.PaasType.BOTH) {
			return
		}
		FileTree tree = project.fileTree(dir: dirName, include: includes, excludes: ignored)
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
				if (lineContainsEndTagToRemove(options, line)) {
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
					if (lineContainsStartTagToRemove(options, line)) {
						remove = true
					} else if (!line.contains("remove::")) {
						newString.append(line).append("\n")
					}
				}
				return
			}
			String newText = newString.toString()
			if (text != newText) {
				inputReader.println("Removing lines from [${file}]")
				file.text = newString.toString()
			}
		}
	}

	private boolean lineContainsStartTagToRemove(Options options, String line) {
		if (line.contains("remove::start[]") || line.contains("remove::start[return]")) {
			return true
		}
		return options.asKeywordsToDelete().any {
			line.toLowerCase().contains("remove::start[${it.toLowerCase()}]")
		}
	}

	private boolean lineContainsEndTagToRemove(Options options, String line) {
		if (line.contains("remove::end[]")) {
			return true
		}
		return options.asKeywordsToDelete().any {
			line.toLowerCase().contains("remove::end[${it.toLowerCase()}]")
		}
	}
}

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
	private final InputReader inputReader

	ProjectCustomizer(Project project, InputReader inputReader) {
		this.optionsReader = new OptionsReader(inputReader)
		this.project = project
		this.fileRemover = new FileRemover(inputReader, project)
		this.linesRemover = new LinesRemover(inputReader, project)
		this.inputReader = inputReader
	}

	void customize() {
		Options options = this.optionsReader.read()
		List<String> filesToRemove = []
		linesRemover.modifyFiles(project.rootDir.absolutePath, options)
		appendCiToolFiles(options, filesToRemove)
		appendPaasFiles(options, filesToRemove)
		fileRemover.deleteFiles(filesToRemove)
	}

	private void appendPaasFiles(Options options, List<String> filesToRemove) {
		switch (options.paasType) {
			case Options.PaasType.CF:
				filesToRemove.addAll(
					paasFiles(Options.PaasType.K8S.name()))
				break
			case Options.PaasType.K8S:
				filesToRemove.addAll(
					paasFiles(Options.PaasType.CF.name()))
				break
			case Options.PaasType.BOTH:
				inputReader.println("Doing nothing since you've picked the BOTH PaaS option")
		}
	}

	private void appendCiToolFiles(Options options, List<String> filesToRemove) {
		switch (options.ciTool) {
			case Options.CiTool.JENKINS:
				filesToRemove.addAll(concourseFiles())
				break
			case Options.CiTool.CONCOURSE:
				filesToRemove.addAll(jenkinsFiles())
				break
			case Options.CiTool.BOTH:
				inputReader.println("Doing nothing since you've picked the BOTH CI tools option")
		}
	}

	private List<String> jenkinsFiles() {
		try {
			List<String> matchingFiles = []
			File asciiDocs = new File(project.rootDir, "docs-sources/src/main/asciidoc")
			asciiDocs.eachFile(appendToList(matchingFiles, "jenkins"))
			new File(project.rootDir, "tools/k8s").eachFile(appendToList(matchingFiles, "jenkins"))
			return [
				new File(project.rootDir, "jenkins").absolutePath,
				new File(asciiDocs, "images/jenkins").absolutePath
			] + matchingFiles
		} catch (Exception e) {
			project.logger.error("Failed to pick the Jenkins files", e)
			return []
		}
	}

	private List<String> concourseFiles() {
		try {
			List<String> matchingFiles = []
			File asciiDocs = new File(project.rootDir, "docs-sources/src/main/asciidoc")
			asciiDocs.eachFile(appendToList(matchingFiles, "concourse"))
			return [
				new File(project.rootDir, "concourse").absolutePath,
				new File(asciiDocs, "images/concourse").absolutePath
			] + matchingFiles
		} catch (Exception e) {
			project.logger.error("Failed to pick the Concourse files", e)
			return []
		}
	}

	private List<String> paasFiles(String paasType) {
		try {
			List<String> matchingFiles = []
			File asciiDocs = new File(project.rootDir, "docs-sources/src/main/asciidoc")
			asciiDocs.eachFile(appendToList(matchingFiles, paasType))
			new File(project.rootDir, "tools").eachFile(appendToList(matchingFiles, paasType))
			new File(project.rootDir, "common").eachFileRecurse(appendToList(matchingFiles, paasType))
			return matchingFiles
		} catch (Exception e) {
			project.logger.error("Failed to pick the PaaS files", e)
			return []
		}
	}

	private Closure appendToList(List<String> matchingFiles, String name) {
		return { File file ->
			if (file.name.toLowerCase().contains(name.toLowerCase())) {
				matchingFiles << file.absolutePath
			}
		}
	}
}

package org.springframework.cloud.pipelines.spinnaker

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
import org.springframework.cloud.projectcrawler.Repository

/**
 * Default view for Spinnaker
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class SpinnakerDefaultView {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults

	SpinnakerDefaultView(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
	}

	void view(List<Repository> repositories) {
		dsl.nestedView('Spinnaker') {
			repositories.each { Repository repo ->
				Coordinates coordinates = Coordinates.fromRepo(repo, pipelineDefaults)
				String viewName = SpinnakerDefaults.viewName(coordinates.gitRepoName)
				String gitRepoName = SpinnakerDefaults.projectName(coordinates.gitRepoName)
				views {
					listView(viewName) {
						jobs {
							regex("${gitRepoName}.*")
						}
						columns {
							status()
							name()
							lastSuccess()
							lastFailure()
							lastBuildConsole()
							buildButton()
						}
					}
				}
			}
		}
	}
}

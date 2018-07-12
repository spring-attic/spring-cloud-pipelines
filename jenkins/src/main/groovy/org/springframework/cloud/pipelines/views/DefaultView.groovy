package org.springframework.cloud.pipelines.views

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.Coordinates
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
import org.springframework.cloud.pipelines.steps.CommonSteps
import org.springframework.cloud.repositorymanagement.Repository

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class DefaultView {
	private final DslFactory dsl
	private final PipelineDefaults pipelineDefaults

	DefaultView(DslFactory dsl, PipelineDefaults pipelineDefaults) {
		this.dsl = dsl
		this.pipelineDefaults = pipelineDefaults
	}

	void view(List<Repository> repositories) {
		dsl.nestedView('Spinnaker') {
			repositories.each { Repository repo ->
				Coordinates coordinates = Coordinates.fromRepo(it, pipelineDefaults)
				String gitRepoName = SpinnakerDefaults.projectName(coordinates.gitRepoName)
				views {
					listView("${gitRepoName}") {
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

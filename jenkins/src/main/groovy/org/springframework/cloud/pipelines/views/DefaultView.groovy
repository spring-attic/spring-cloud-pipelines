package org.springframework.cloud.pipelines.views

import groovy.transform.CompileStatic
import javaposse.jobdsl.dsl.DslFactory

import org.springframework.cloud.pipelines.common.BashFunctions
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.steps.CommonSteps

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

	void view(String gitRepoName) {
		dsl.listView("spinnnaker-${gitRepoName}") {
			jobs {
				regex("spinnaker-${gitRepoName}.*")
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

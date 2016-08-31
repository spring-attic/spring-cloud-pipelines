package io.springframework.cloud.sonar

import io.springframework.cloud.common.HashicorpTrait
import javaposse.jobdsl.dsl.DslFactory

/**
 * @author Marcin Grzejszczak
 */
class ConsulSonarBuildMaker extends SonarBuildMaker implements HashicorpTrait {

	ConsulSonarBuildMaker(DslFactory dsl) {
		super(dsl)
	}

	void buildSonar() {
		super.buildSonar('spring-cloud-consul')
	}

	@Override
	Closure defaultSteps() {
		return buildStep {
			shell postConsulShell()
		} << super.defaultSteps() <<  buildStep {
			shell preConsulShell()
		}
	}

	@Override
	protected String postAction() {
		return postConsulShell()
	}
}

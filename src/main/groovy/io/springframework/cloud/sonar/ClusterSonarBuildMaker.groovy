package io.springframework.cloud.sonar

import io.springframework.cloud.common.ClusterTrait
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class ClusterSonarBuildMaker extends SonarBuildMaker implements ClusterTrait {

	ClusterSonarBuildMaker(DslFactory dsl) {
		super(dsl)
	}

	void buildSonar() {
		super.buildSonar('spring-cloud-consul')
	}

	@Override
	Closure defaultSteps() {
		return buildStep {
			shell postClusterShell()
		} << super.defaultSteps() <<  buildStep {
			shell preClusterShell()
		}
	}

	@Override
	protected String postAction() {
		return postClusterShell()
	}
}

package io.springframework.cloud.e2e

import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class NetflixEndToEndBuildMaker extends EndToEndBuildMaker {

	NetflixEndToEndBuildMaker(DslFactory dsl) {
		super(dsl)
	}

	void build(String cronExpr) {
		buildWithGradleAndMavenTests('spring-cloud-netflix', "scripts/runAcceptanceTests.sh", cronExpr)
	}

}

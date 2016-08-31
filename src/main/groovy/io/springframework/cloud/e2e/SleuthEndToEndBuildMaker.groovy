package io.springframework.cloud.e2e

import javaposse.jobdsl.dsl.DslFactory

/**
 * @author Marcin Grzejszczak
 */
class SleuthEndToEndBuildMaker extends EndToEndBuildMaker {
	SleuthEndToEndBuildMaker(DslFactory dsl) {
		super(dsl)
	}

	void buildSleuth(String cronExpr) {
		super.build("spring-cloud-sleuth", cronExpr)
	}

	void buildSleuthStream(String cronExpr) {
		super.build("spring-cloud-sleuth-stream", 'spring-cloud-sleuth', "scripts/runAcceptanceTestsStream.sh", cronExpr)
	}

	void buildSleuthStreamKafka(String cronExpr) {
		super.build("spring-cloud-sleuth-stream-with-kafka", 'spring-cloud-sleuth', "scripts/runAcceptanceTestsStreamKafka.sh", cronExpr)
	}

}

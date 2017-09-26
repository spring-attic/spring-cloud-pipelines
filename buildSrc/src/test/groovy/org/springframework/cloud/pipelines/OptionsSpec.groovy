package org.springframework.cloud.pipelines

import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class OptionsSpec extends Specification {
	def "should return options as a list of keywords"() {
		given:
			Options options = Options.builder()
				.paasType(Options.PaasType.K8S)
				.ciTool(Options.CiTool.CONCOURSE)
				.build()
		expect:
			options.asKeywordsToDelete() == ["CF", "JENKINS"]
	}

	def "should return empty list options as a list of keywords when BOTH is picked"() {
		given:
			Options options = Options.builder()
				.build()
		expect:
			options.asKeywordsToDelete() == []
	}
}

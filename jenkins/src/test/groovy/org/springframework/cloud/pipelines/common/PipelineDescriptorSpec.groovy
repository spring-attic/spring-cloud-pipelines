package org.springframework.cloud.pipelines.common

import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class PipelineDescriptorSpec extends Specification {
	def "should parse the pipeline descriptor"() {
		given:
			String yml = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

# lowercase name of the environment
test:
  # list of required services
  services:
    # Prepared for PCF DEV
    - name: github-rabbitmq
      type: broker
      broker: p-rabbitmq
      plan: standard
    - name: github-eureka
      type: app
      coordinates: com.example.eureka:github-eureka:0.0.1.M1
      pathToManifest: sc-pipelines/manifest-eureka.yml

stage:
  services:
  # Prepared for PCF DEV
    - name: github-rabbitmq
      type: broker
      broker: p-rabbitmq
      plan: standard
    - name: github-eureka
      type: app
      coordinates: com.example.eureka:github-eureka:0.0.1.M1
      pathToManifest: sc-pipelines/manifest-eureka.yml
"""
		when:
			PipelineDescriptor descriptor = PipelineDescriptor.from(yml)
		then:
			descriptor.test.services.size() == 2
			descriptor.stage.services.size() == 2
	}
}

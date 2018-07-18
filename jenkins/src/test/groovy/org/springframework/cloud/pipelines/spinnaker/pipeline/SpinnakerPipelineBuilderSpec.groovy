package org.springframework.cloud.pipelines.spinnaker.pipeline

import groovy.json.JsonSlurper
import org.skyscreamer.jsonassert.JSONAssert
import spock.lang.Specification

import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.repositorymanagement.Repository

/**
 * @author Marcin Grzejszczak
 */
class SpinnakerPipelineBuilderSpec extends Specification {

	def expectedPipeline = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline.json').text
	String descriptorYaml = """
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

	def "should produce a spinnaker pipeline"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYaml)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			defaults.addEnvVar("SPINNAKER_TEST_DEPLOYMENT_ACCOUNT", "calabasasaccount")
			defaults.addEnvVar("SPINNAKER_STAGE_DEPLOYMENT_ACCOUNT", "calabasasaccount")
			defaults.addEnvVar("SPINNAKER_PROD_DEPLOYMENT_ACCOUNT", "calabasasaccount")
			defaults.addEnvVar("PAAS_TEST_SPACE_PREFIX", "sc-pipelines-test")
			defaults.addEnvVar("PAAS_STAGE_SPACE", "sc-pipelines-stage")
			defaults.addEnvVar("PAAS_PROD_SPACE", "sc-pipelines-prod")
			defaults.addEnvVar("PAAS_TEST_ORG", "scpipelines")
			defaults.addEnvVar("PAAS_STAGE_ORG", "scpipelines")
			defaults.addEnvVar("PAAS_PROD_ORG", "scpipelines")
			defaults.addEnvVar("SPINNAKER_JENKINS_MASTER", "Spinnaker-Jenkins")
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipeline, pipeline)
	}

	void assertThatJsonsAreEqual(String expected, String actual) {
		JSONAssert.assertEquals(expected, actual, false)
	}
}

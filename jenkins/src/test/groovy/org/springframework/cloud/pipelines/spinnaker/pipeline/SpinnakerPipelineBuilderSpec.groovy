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
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipeline, pipeline)
	}

	def expectedPipelineWithoutStageServices = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_no_stage_services.json').text
	String descriptorYamlWithoutStageServices = """
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
"""

	def "should produce a spinnaker pipeline without stage services"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithoutStageServices)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithoutStageServices, pipeline)
	}

	def expectedPipelineWithoutTestServices = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_no_test_services.json').text
	String descriptorYamlWithoutTestServices = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

# lowercase name of the environment
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

	def "should produce a spinnaker pipeline without test services"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithoutTestServices)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithoutTestServices, pipeline)
	}

	def expectedPipelineWithAutoStage = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_auto_stage.json').text
	String descriptorYamlWithAutoStage = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

pipeline:
  auto_stage: true

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

	def "should produce a spinnaker pipeline with auto stage"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithAutoStage)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithAutoStage, pipeline)
	}

	def expectedPipelineWithAutoProd = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_auto_prod.json').text
	String descriptorYamlWithAutoProd = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

pipeline:
  auto_prod: true

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

	def "should produce a spinnaker pipeline with auto prod"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithAutoProd)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithAutoProd, pipeline)
	}

	def expectedPipelineWithoutRollback = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_no_rollback_step.json').text
	String descriptorYamlWithoutRollback = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

pipeline:
  rollback_step: false

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

	def "should produce a spinnaker pipeline without rollback step"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithoutRollback)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithoutRollback, pipeline)
	}

	def expectedPipelineWithoutStage = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline_no_stage_step.json').text
	String descriptorYamlWithoutStage = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end testsx
# on the STAGE environment to pass

pipeline:
  stage_step: false

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

	def "should produce a spinnaker pipeline without stage step"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithoutStage)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults).spinnakerPipeline()
		then:
			assertThatJsonsAreEqual(expectedPipelineWithoutStage, pipeline)
	}

	void setupEnvVars(PipelineDefaults defaults) {
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
	}

	void assertThatJsonsAreEqual(String expected, String actual) {
		JSONAssert.assertEquals(expected, actual, false)
	}
}

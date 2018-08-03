package org.springframework.cloud.pipelines.spinnaker.pipeline

import groovy.json.JsonSlurper
import org.junit.Rule
import org.junit.rules.TestName
import org.skyscreamer.jsonassert.JSONAssert
import spock.lang.Specification

import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.projectcrawler.Repository

/**
 * @author Marcin Grzejszczak
 */
class SpinnakerPipelineBuilderSpec extends Specification {

	@Rule TestName testName = new TestName()

	Map<String, String> additionalFiles = ["manifest.yml" : """
---
applications:
  - name: github-webhook
    instances: 1
    disk_quota: 2048M
    memory: 1024M
    domain: foo.com
    path: /a/b/c
    env: 
      SPRING_PROFILES_ACTIVE: cloud
      DEBUG: "true"
    services:
      - github-rabbitmq
      - github-eureka
"""]

	void storeJsonWithPipeline(String name, String json) {
		File file = new File("build/spinnaker-pipeline")
		file.mkdirs()
		new File(file, "${name}.json").text = json
	}

	def expectedPipeline = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline.json').text
	String descriptorYaml = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end tests
# on the STAGE environment to pass

pipeline:
  auto_stage: false

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

	def "should produce a spinnaker pipeline with manual steps"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYaml)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
			defaults.addEnvVar("AUTO_DEPLOY_TO_STAGE", "false")
			defaults.addEnvVar("AUTO_DEPLOY_TO_PROD", "false")
			defaults.addEnvVar("SPINNAKER_TEST_HOSTNAME", "test.foo.com")
			defaults.addEnvVar("SPINNAKER_STAGE_HOSTNAME", "stage.foo.com")
			defaults.addEnvVar("SPINNAKER_PROD_HOSTNAME", "prod.foo.com")
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline", pipeline)
			assertThatJsonsAreEqual(expectedPipeline, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithoutStageServices = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_no_stage_services.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_no_stage_services", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithoutStageServices, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithoutTestServices = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_no_test_services.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_no_test_services", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithoutTestServices, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithAutoStage = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_auto_stage.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_auto_stage", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithAutoStage, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithAutoProd = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_auto_prod.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_auto_prod", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithAutoProd, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithoutRollback = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_no_rollback_step.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_no_rollback_step", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithoutRollback, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	void refIdsAreUniqe(String pipeline) {
		List<String> refIds = new JsonSlurper().parseText(pipeline).stages.collect { it.refId }
		assert (refIds.clone() as List).unique().size() == refIds.size()
	}

	def expectedPipelineWithoutStage = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_no_stage_step.json').text
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
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_no_stage_step", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithoutStage, pipeline)
		and:
			refIdsAreUniqe(pipeline)
	}

	def expectedPipelineWithoutTest = SpinnakerPipelineBuilderSpec.getResource('/spinnaker/pipeline/pipeline_no_test_step.json').text
	String descriptorYamlWithoutTest = """
# This file describes which services are required by this application
# in order for the smoke tests on the TEST environment and end to end testsx
# on the STAGE environment to pass

pipeline:
  test_step: false

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

	def "should produce a spinnaker pipeline without test step"() {
		given:
			PipelineDescriptor descriptor = PipelineDescriptor.from(descriptorYamlWithoutTest)
			Repository repository = new Repository("github-webhook", "", "", "")
			PipelineDefaults defaults = new PipelineDefaults([:])
		and:
			setupEnvVars(defaults)
		when:
			String pipeline = new SpinnakerPipelineBuilder(descriptor, repository, defaults, additionalFiles).spinnakerPipeline()
		then:
			storeJsonWithPipeline("pipeline_no_test_step", pipeline)
			assertThatJsonsAreEqual(expectedPipelineWithoutTest, pipeline)
		and:
			refIdsAreUniqe(pipeline)
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
		defaults.addEnvVar("AUTO_DEPLOY_TO_STAGE", "false")
		defaults.addEnvVar("AUTO_DEPLOY_TO_PROD", "false")
	}

	void assertThatJsonsAreEqual(String expected, String actual) {
		JSONAssert.assertEquals(expected, actual, false)
	}
}

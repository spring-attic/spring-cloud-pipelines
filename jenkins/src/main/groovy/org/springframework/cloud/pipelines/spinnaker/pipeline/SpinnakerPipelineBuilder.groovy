package org.springframework.cloud.pipelines.spinnaker.pipeline

import com.fasterxml.jackson.annotation.JsonInclude
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import groovy.transform.CompileStatic

import org.springframework.cloud.pipelines.common.EnvironmentVariables
import org.springframework.cloud.pipelines.common.PipelineDefaults
import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.common.StepEnabledChecker
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Artifact
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Capacity
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Cluster
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Manifest
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Root
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Stage
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.StageEnabled
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Trigger
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.cf.CloudFoundryManifest
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.cf.ListOfCloudFoundryManifest
import org.springframework.cloud.projectcrawler.Repository

/**
 * Given the env variables produces a JSON with a Spinnaker
 * opinionated deployment pipeline
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class SpinnakerPipelineBuilder {

	private final PipelineDescriptor pipelineDescriptor
	private final Repository repository
	private final PipelineDefaults defaults
	private final ObjectMapper objectMapper = new ObjectMapper()
	private final ObjectMapper yamlObjectMapper = new ObjectMapper(new YAMLFactory())
	private final StepEnabledChecker stepEnabledChecker
	private final CloudFoundryManifest manifest

	SpinnakerPipelineBuilder(PipelineDescriptor pipelineDescriptor, Repository repository,
							 PipelineDefaults defaults, Map<String, String> additionalFiles) {
		this.pipelineDescriptor = pipelineDescriptor
		this.repository = repository
		this.defaults = defaults
		this.objectMapper.enable(SerializationFeature.INDENT_OUTPUT)
		this.objectMapper.setSerializationInclusion(JsonInclude.Include.NON_NULL)
		this.objectMapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS)
		this.yamlObjectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
		this.stepEnabledChecker = new StepEnabledChecker(pipelineDescriptor, defaults)
		this.manifest = manifest(additionalFiles)
	}

	CloudFoundryManifest manifest(Map<String, String> additionalFiles) {
		String manifest = additionalFiles.get("manifest.yaml") ?:
			additionalFiles.get("manifest.yml")
		if (!manifest) {
			return new CloudFoundryManifest()
		}
		ListOfCloudFoundryManifest list = yamlObjectMapper.readerFor(ListOfCloudFoundryManifest)
			 .readValue(manifest) as ListOfCloudFoundryManifest
		return list.applications.isEmpty() ? new CloudFoundryManifest() : list.applications.get(0)
	}

	String spinnakerPipeline() {
		return objectMapper.writerFor(Root).writeValueAsString(root())
	}

	private Root root() {
		Root root = new Root()
		root.triggers.add(trigger())
		root.stages = stages()
		return root
	}

	private List<Stage> stages() {
		List<Stage> stages = []
		int firstRefId = 0
		// each tuple represents the id of the job and list / single stage
		Tuple2<Integer, Stage> testServices = createTestServices(firstRefId, stages)
		Tuple2<Integer, Stage> testDeployment = deployToTest(testServices, stages)
		Tuple2<Integer, Stage> testsOnTest = testsOnTest(testDeployment, stages)
		Tuple2<Integer, Stage> testDeploymentRollback = deployToTestLatestProdVersion(testsOnTest, stages)
		Tuple2<Integer, Stage> rollbackTests = testOnTestLatestProdVersion(testDeploymentRollback, stages)
		Tuple2<Integer, Stage> waitingForStage = waitForStage(rollbackTests, stages)
		Tuple2<Integer, Stage> stageServices = createStageServices(waitingForStage, stages)
		Tuple2<Integer, Stage> stageDeployment = deployToStage(waitingForStage, stageServices, stages)
		Tuple2<Integer, Stage> prepareForE2e = prepareForEndToEndTests(stageDeployment, stages)
		Tuple2<Integer, Stage> e2eTests = runEndToEndTests(prepareForE2e, stages)
		Tuple2<Integer, Stage> approveProd = approveProduction(e2eTests, stages)
		Tuple2<Integer, Stage> deployToProd = deployToProd(approveProd, stages)
		Tuple2<Integer, Stage> pushTag = pushTag(deployToProd, stages)
		Tuple2<Integer, Stage> approveRollback = approveRollback(deployToProd, pushTag, stages)
		Tuple2<Integer, Stage> rollback = rollback(approveRollback, stages)
		removeTag(rollback, stages)
		return stages.findAll { it }
	}

	private Tuple2<Integer, Stage> pushTag(Tuple2<Integer, Stage> previous, List<Stage> stages) {
		Tuple2<Integer, Stage> stage =
			callJenkins("Push prod tag", "prod-tag-repo", previous.first)
		stages.add(stage.second)
		return stage
	}

	private Tuple2<Integer, Stage> removeTag(Tuple2<Integer, Stage> previous, List<Stage> stages) {
		Tuple2<Integer, Stage> stage =
			callJenkins("Remove prod tag", "prod-env-remove-tag", previous.first)
		stages.add(stage.second)
		stage.second.stageEnabled = new StageEnabled(
			type: "expression",
			expression: latestProdEnvVarPresent()
		)
		return stage
	}

	private Tuple2<Integer, Stage> rollback(Tuple2<Integer, Stage> idToReference, List<Stage> stages) {
		Tuple2<Integer, Stage> rollback =
			prodDeployment("Rollback", idToReference.first, idToReference.first,
				latestProdVersionArtifactPattern())
		stages.add(rollback.second)
		return rollback
	}

	private Tuple2<Integer, Stage> deployToProd(Tuple2<Integer, Stage> approveProd, List<Stage> stages) {
		Tuple2<Integer, Stage> deployToProd =
			prodDeployment("Deploy to prod", approveProd.first, approveProd.first, defaultArtifactPattern())
		stages.add(deployToProd.second)
		return deployToProd
	}

	private Tuple2<Integer, Stage> approveProduction(Tuple2<Integer, Stage> e2eTests, List<Stage> stages) {
		Tuple2<Integer, Stage> approveProd = manualJudgement(
			stepEnabledChecker.autoProdSet(), "Approve production", e2eTests.first)
		stages.add(approveProd.second)
		return approveProd
	}

	private Tuple2<Integer, Stage> approveRollback(Tuple2<Integer, Stage> previous, Tuple2<Integer, Stage> current, List<Stage> stages) {
		Tuple2<Integer, Stage> approve = manualJudgement(false, "Approve rollback", previous.first, current.first + 1)
		stages.add(approve.second)
		return approve
	}

	private Tuple2<Integer, Stage> runEndToEndTests(Tuple2<Integer, Stage> prepareForE2e, List<Stage> stages) {
		Tuple2<Integer, Stage> e2eTests = runTests("stage", "End to end tests on stage",
			"test", prepareForE2e.first, stageSet())
		stages.add(e2eTests.second)
		return e2eTests
	}

	private boolean stageSet() {
		return stepEnabledChecker.stageStepSet()
	}

	private boolean shouldSkipManualJudgementForStage() {
		// there's no stage or stage is automatic
		return stepEnabledChecker.stageStepMissing() || stepEnabledChecker.autoStageSet()
	}

	private Tuple2<Integer, Stage> prepareForEndToEndTests(Tuple2<Integer, Stage> stageDeployment, List<Stage> stages) {
		Tuple2<Integer, Stage> prepareForE2e = manualJudgement(shouldSkipManualJudgementForStage(),
			"Prepare for end to end tests", stageDeployment.first)
		stages.add(prepareForE2e.second)
		return prepareForE2e
	}

	private Tuple2<Integer, Stage> deployToStage(Tuple2<Integer, Stage> waitingForStage, Tuple2<Integer, Stage> stageServices, List<Stage> stages) {
		Tuple2<Integer, Stage> stageDeployment =
			deploymentStage("Deploy to stage", waitingForStage.first,
				stageServices.first, stageSet())
		stages.add(stageDeployment.second)
		return stageDeployment
	}

	private Tuple2<Integer, Stage> createStageServices(Tuple2<Integer, Stage> waitingForStage, List<Stage> stages) {
		List<PipelineDescriptor.Service> pipeServices = pipelineDescriptor.stage.services
		if (!pipeServices || stepEnabledChecker.stageStepMissing()) {
			return new Tuple2(waitingForStage.first, null)
		}
		Tuple2<Integer, Stage> stage =
			callJenkins("Prepare stage environment", "stage-prepare", waitingForStage.first)
		stages.addAll(stage.second)
		return stage
	}

	private Tuple2<Integer, Stage> waitForStage(Tuple2<Integer, Stage> rollbackTests, List<Stage> stages) {
		Tuple2<Integer, Stage> waitingForStage = manualJudgement(shouldSkipManualJudgementForStage(),
			"Wait for stage env", rollbackTests.first)
		stages.add(waitingForStage.second)
		return waitingForStage
	}

	private Tuple2<Integer, Stage> testOnTestLatestProdVersion(Tuple2<Integer, Stage> testDeploymentRollback, List<Stage> stages) {
		Tuple2<Integer, Stage> rollbackTests = runTests("test", "Run rollback tests on test",
			"rollback-test", testDeploymentRollback.first, stepEnabledChecker.rollbackStepSet(),
			latestProdEnvVarPresent())
		if (rollbackTests.second) {
			if (!rollbackTests.second.parameters) {
				rollbackTests.second.parameters = [:]
			}
			rollbackTests.second.parameters.put(EnvironmentVariables.PASSED_LATEST_PROD_TAG_ENV_VAR,
				propertyFromTrigger(EnvironmentVariables.PASSED_LATEST_PROD_TAG_ENV_VAR))
		}
		stages.add(rollbackTests.second)
		return rollbackTests
	}

	private Tuple2<Integer, Stage> deployToTestLatestProdVersion(Tuple2<Integer, Stage> testsOnTest, List<Stage> stages) {
		Tuple2<Integer, Stage> testDeploymentRollback =
			rollbackDeploymentStage("Deploy to test latest prod version",
				testsOnTest.first, stepEnabledChecker.rollbackStepSet())
		stages.add(testDeploymentRollback.second)
		return testDeploymentRollback
	}

	private Tuple2<Integer, Stage> testsOnTest(Tuple2<Integer, Stage> testDeployment, List<Stage> stages) {
		Tuple2<Integer, Stage> testsOnTest = runTests("test", "Run tests on test",
			"test", testDeployment.first, stepEnabledChecker.testStepSet())
		stages.add(testsOnTest.second)
		return testsOnTest
	}

	private Tuple2<Integer, Stage> deployToTest(Tuple2<Integer, Stage> testService, List<Stage> stages) {
		Tuple2<Integer, Stage> testDeployment = testDeploymentStage(testService.first)
		stages.add(testDeployment.second)
		return testDeployment
	}

	private Tuple2<Integer, Stage> createTestServices(int firstRefId, List<Stage> stages) {
		List<PipelineDescriptor.Service> pipeServices = pipelineDescriptor.test.services
		if (!pipeServices || stepEnabledChecker.testStepMissing()) {
			return new Tuple2(firstRefId, null)
		}
		Tuple2<Integer, Stage> stage =
			callJenkins("Prepare test environment", "test-prepare", firstRefId)
		stages.addAll(stage.second)
		return stage
	}

	private Cluster cluster(String account, String org, String space, List<String> routes,
							String deploymentStrategy, String artifactPattern) {
		return new Cluster(
			account: account,
			application: "${alphaNumericOnly(this.repository.name)}",
			artifact: new Artifact(
				account: "jenkins",
				pattern: artifactPattern,
				type: "trigger"
			),
			capacity: new Capacity(
				desired: "1",
				max: "1",
				min: "1"
			),
			cloudProvider: "cloudfoundry",
			detail: "",
			manifest: new Manifest(
				diskQuota: "1024M",
				//env: manifest.env ?: [:] as Map<String, String>,
				instances: 1,
				memory: manifest.memory ?: "1024M",
				routes: routes,
				services: manifest.services,
				type: "direct",
			),
			provider: "cloudfoundry",
			region: "${org} > ${space}",
			stack: "",
			strategy: deploymentStrategy
		)
	}

	protected String defaultArtifactPattern() {
		return "^${this.repository.name}.*VERSION.jar\$"
	}

	private String alphaNumericOnly(String string) {
		return string.replace("_", "")
					.replace("-", "")
	}

	private Tuple2<Integer, Stage> testDeploymentStage(int lastRefId) {
		if (stepEnabledChecker.testStepMissing()) {
			return new Tuple2<>(lastRefId, null)
		}
		int refId = pipelineDescriptor.test.services.empty ?
			1 : lastRefId + 1
		Stage stage = new Stage(
			name: "Deploy to test",
			refId: "${refId}",
			requisiteStageRefIds: pipelineDescriptor.test.services.empty ?
				[] as List<String> : intToRange(1, lastRefId),
			type: "deploy",
			clusters: [
				cluster(defaults.spinnakerTestDeploymentAccount(),
					defaults.cfTestOrg(), testSpaceName(),
					route(testSpaceName(), defaults.spinnakerTestHostname()), "highlander",
				defaultArtifactPattern())
			]
		)
		return new Tuple2(refId, stage)
	}

	private String testSpaceName() {
		return defaults.cfTestSpacePrefix() + "-" + repository.name
	}

	private Tuple2<Integer, Stage> deploymentStage(String text, int firstRefId, int lastRefId,
												   boolean present) {
		if (!present) {
			return new Tuple2<>(firstRefId, null)
		}
		int refId = lastRefId + 1
		int startRange = firstRefId != lastRefId ? firstRefId + 1 : firstRefId
		Stage stage = new Stage(
			name: text,
			refId: "${refId}",
			requisiteStageRefIds: intToRange(startRange, lastRefId),
			type: "deploy",
			clusters: [
				cluster(defaults.spinnakerStageDeploymentAccount(),
					defaults.cfStageOrg(), defaults.cfStageSpace(),
					route(stageSpaceName(), defaults.spinnakerStageHostname()), "highlander",
					defaultArtifactPattern())
			]
		)
		return new Tuple2(refId, stage)
	}

	private String stageSpaceName() {
		return repository.name + "-" + defaults.cfStageSpace()
	}

	private Tuple2<Integer, Stage> prodDeployment(String text, int idToReference, int lastRefId,
												  String artifactPattern) {
		int refId = lastRefId + 1
		Stage stage = new Stage(
			name: text,
			refId: "${refId}",
			requisiteStageRefIds: [
				"${idToReference}".toString()
			],
			type: "deploy",
			clusters: [
				cluster(defaults.spinnakerProdDeploymentAccount(),
					defaults.cfProdOrg(), defaults.cfProdSpace(),
					manifest.routes ?: route(repository.name, defaults.spinnakerProdHostname()),
				pipelineDescriptor.prod.deployment_strategy ?: "highlander",
					artifactPattern)
			]
		)
		return new Tuple2(refId, stage)
	}

	private List<String> route(String name, String hostname) {
		return [name + "." + hostname]
	}

	private Tuple2<Integer, Stage> rollbackDeploymentStage(String text, int firstRefId, boolean present) {
		if (!present) {
			return new Tuple2(firstRefId, null)
		}
		int refId = firstRefId + 1
		Stage stage = new Stage(
			name: text,
			refId: "${refId}",
			requisiteStageRefIds: [
				"${firstRefId}".toString()
			],
			type: "deploy",
			clusters: [
				cluster(defaults.spinnakerProdDeploymentAccount(),
					defaults.cfTestOrg(), testSpaceName(),
					route(testSpaceName(), defaults.spinnakerTestHostname()),
					pipelineDescriptor.prod.deployment_strategy ?: "highlander",
					latestProdVersionArtifactPattern())
			],
			stageEnabled: new StageEnabled(
				type: "expression",
				expression: latestProdEnvVarPresent()
			)
		)
		return new Tuple2(refId, stage)
	}

	protected String latestProdVersionArtifactPattern() {
		return "^${this.repository.name}.*VERSION-latestprodversion.jar\$"
	}

	private String propertyFromTrigger(String key) {
		return """\${trigger.properties['${
			key
		}']}"""
	}

	private String latestProdEnvVarPresent() {
		return propertyFromTrigger(EnvironmentVariables.LATEST_PROD_VERSION_ENV_VAR)
	}

	private Tuple2<Integer, Stage> manualJudgement(boolean skip,
												   String text, int firstRefId, Integer current = null) {
		if (skip) {
			return new Tuple2(firstRefId, null)
		}
		int refId = current != null ? current : firstRefId + 1
		Stage stage = new Stage(
			failPipeline: true,
			judgmentInputs: [],
			name: text,
			notifications: [],
			refId: "${refId}",
			requisiteStageRefIds: firstRefId == 0 ? [] as List<String> : [
				"${firstRefId}".toString()
			],
			type: "manualJudgment",
			stageEnabled: new StageEnabled(
				type: "expression",
				expression: latestProdEnvVarPresent()
			)
		)
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> callJenkins(String text, String jobName, int firstRefId) {
		int refId = firstRefId + 1
		Stage stage = new Stage(
			continuePipeline: false,
			failPipeline: true,
			job: "${SpinnakerDefaults.projectName(repository.name)}-${jobName}",
			master: defaults.spinnakerJenkinsMaster(),
			name: "${text}",
			parameters: [
				(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR) :
					propertyFromTrigger(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR)
			],
			refId: "${refId}",
			waitForCompletion: true,
			type: "jenkins"
		)
		if (firstRefId > 0) {
			stage.requisiteStageRefIds = [
				"${firstRefId}".toString()
			]
		}
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> runTests(String env, String text, String testName,
											int firstRefId, boolean present = true,
											String stageEnabledExpression = "") {
		if (!present) {
			return new Tuple2(firstRefId, null)
		}
		int refId = firstRefId + 1
		Stage stage = new Stage(
			continuePipeline: false,
			failPipeline: true,
			job: "${SpinnakerDefaults.projectName(repository.name)}-${env}-env-${testName}",
			master: defaults.spinnakerJenkinsMaster(),
			name: "${text}",
			parameters: [
				(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR) :
					propertyFromTrigger(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR)
			],
			refId: "${refId}",
			requisiteStageRefIds: [
				"${firstRefId}".toString()
			],
			waitForCompletion: true,
			type: "jenkins"
		)
		if (stageEnabledExpression) {
			stage.stageEnabled = new StageEnabled(
				type: "expression",
				expression: stageEnabledExpression
			)
		}
		return new Tuple2(refId, stage)
	}

	private List<String> intToRange(int firstRefId, int lastRefId) {
		return (firstRefId..lastRefId).collect {
			"${it}".toString()
		}
	}

	private Trigger trigger() {
		return new Trigger(
			enabled: true,
			job: triggerJobName(),
			master: defaults.spinnakerJenkinsMaster(),
			type: "jenkins",
			propertyFile: "trigger.properties"
		)
	}

	protected String triggerJobName() {
		return "${SpinnakerDefaults.projectName(repository.name)}-build"
	}
}

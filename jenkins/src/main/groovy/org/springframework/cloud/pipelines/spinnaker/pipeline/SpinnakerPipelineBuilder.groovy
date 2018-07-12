package org.springframework.cloud.pipelines.spinnaker.pipeline

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.SerializationFeature
import groovy.transform.CompileStatic

import org.springframework.cloud.pipelines.common.PipelineDescriptor
import org.springframework.cloud.pipelines.spinnaker.SpinnakerDefaults
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Artifact
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Capacity
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Cluster
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Manifest
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.PayloadConstraints
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Root
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Stage
import org.springframework.cloud.pipelines.spinnaker.pipeline.model.Trigger
import org.springframework.cloud.repositorymanagement.Repository

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class SpinnakerPipelineBuilder {

	private final PipelineDescriptor pipelineDescriptor
	private final Repository repository
	private final ObjectMapper objectMapper = new ObjectMapper()

	SpinnakerPipelineBuilder(PipelineDescriptor pipelineDescriptor, Repository repository) {
		this.pipelineDescriptor = pipelineDescriptor
		this.repository = repository
		this.objectMapper.enable(SerializationFeature.INDENT_OUTPUT)
		this.objectMapper.disable(SerializationFeature.FAIL_ON_EMPTY_BEANS)
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
		// Test Create Service 1 (x)
		// Test Create Service 2 (x)
		int firstRefId = 1
		Tuple2<Integer, List<Stage>> testServices = createStageServices("test", firstRefId,
			pipelineDescriptor.test.services)
		stages.addAll(testServices.second)
		// Deploy to test
		Tuple2<Integer, Stage> testDeployment = testDeploymentStage(testServices.first)
		stages.add(testDeployment.second)
		// Test on test
		Tuple2<Integer, Stage> testsOnTest = runTests("Run testServices on test", "test",
			testDeployment.first)
		stages.add(testsOnTest.second)
		// Deploy to test latest prod version
		Tuple2<Integer, Stage> testDeploymentRollback =
			rollbackDeploymentStage("Deploy to test latest prod version",
				testsOnTest.first)
		stages.add(testDeploymentRollback.second)
		// Test on test latest prod version
		Tuple2<Integer, Stage> rollbackTests = runTests("Run rollback testServices on test", "rollback-test",
			testDeploymentRollback.first)
		stages.add(rollbackTests.second)
		// Wait for stage env
		Tuple2<Integer, Stage> waitingForStage = manualJudgement("Wait for stage env",
			rollbackTests.first)
		stages.add(waitingForStage.second)
		// Stage Create Service 1
		// Stage Create Service 2
		Tuple2<Integer, List<Stage>> stageServices = createStageServices("stage", waitingForStage.first,
			pipelineDescriptor.stage.services)
		stages.addAll(stageServices.second)
		// Deploy to stage
		Tuple2<Integer, Stage> stageDeployment =
			deploymentStage("Deploy to stage", waitingForStage.first, stageServices.first)
		stages.add(stageDeployment.second)
		// Prepare for end to end tests
		Tuple2<Integer, Stage> prepareForE2e = manualJudgement("Prepare for end to end tests",
			stageDeployment.first)
		stages.add(prepareForE2e.second)
		// Run end to end tests
		Tuple2<Integer, Stage> e2eTests = runTests("End to end tests on stage", "e2e",
			prepareForE2e.first)
		// Approve production
		Tuple2<Integer, Stage> approveProd = manualJudgement("Approve production",
			e2eTests.first)
		stages.add(approveProd.second)
		// Deploy to prod
		Tuple2<Integer, Stage> deployToProd =
			deploymentStage("Deploy to stage", approveProd.first)
		stages.add(deployToProd.second)
		// Rollback
		Tuple2<Integer, Stage> rollback =
			deploymentStage("Rollback", approveProd.first)
		stages.add(rollback.second)
		return stages
	}

	private Tuple2<Integer, List<Stage>> createStageServices(String env, int firstId,
															 List<PipelineDescriptor.Service> pipeServices) {
		if (!pipeServices) {
			return new Tuple2(firstId, [])
		}
		List<Stage> testServices = []
		List<PipelineDescriptor.Service> services = pipeServices
		int refId = 1
		for (int i = 0; i < services.size(); i++) {
			refId = i + 1 + firstId
			PipelineDescriptor.Service service = services[i]
			testServices.add(new Stage(
				command: "echo \"Creating service [${service.name}]\"",
				failPipeline: true,
				name: "Create ${env} service [${refId}]",
				refId: "${refId}",
				requisiteStageRefIds: [
				        "${firstId}".toString()
				],
				scriptPath: "shell",
				type: "script",
				user: "anonymous",
				waitForCompletion: true
			))
		}
		return new Tuple2(refId, testServices)
	}

	private Cluster cluster() {
		return new Cluster(
			account: "calabasasaccount",
			application: "github_webhook",
			artifact: new Artifact(
				account: "",
				pattern: "github-webhook.*.jar",
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
				env: [],
				instances: 1,
				memory: "1024M",
				services: [],
				type: "direct"
			),
			provider: "cloudfoundry",
			region: "system/system",
			spaceId: "85fbe929-2abb-4ce0-8f4f-414528999098",
			stack: "",
			strategy: "highlander"
		)
	}

	private Tuple2<Integer, Stage> deploymentStage(String text, int firstRefId) {
		return deploymentStage(text, firstRefId, firstRefId + 1)
	}

	private Tuple2<Integer, Stage> testDeploymentStage(int lastRefId) {
		int refId = pipelineDescriptor.test.services.empty ?
			1 :lastRefId + 1
		Stage stage = new Stage(
			name: "Deploy to test",
			refId: "${refId}",
			requisiteStageRefIds: intToRange(1, lastRefId),
			type: "deploy",
			clusters: [
			        cluster()
			]
		)
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> deploymentStage(String text, int firstRefId, int lastRefId) {
		int refId = lastRefId + (firstRefId == lastRefId ? 2 : 1)
		Stage stage = new Stage(
			name: text,
			refId: "${refId}",
			requisiteStageRefIds: intToRange(firstRefId, lastRefId),
			type: "deploy",
			clusters: [
			        cluster()
			]
		)
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> rollbackDeploymentStage(String text, int firstRefId) {
		int refId = firstRefId + 1
		Stage stage = new Stage(
			name: text,
			refId: "${refId}",
			requisiteStageRefIds: [
			        "${firstRefId}".toString()
			],
			type: "deploy",
			clusters: [
			        cluster()
			]
		)
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> manualJudgement(String text, int firstRefId) {
		int refId = firstRefId + 1
		Stage stage = new Stage(
			failPipeline: true,
			judgmentInputs: [],
			name: text,
			notifications: [],
			refId: "${refId}",
			requisiteStageRefIds: [
				"${firstRefId}".toString()
			],
			type: "manualJudgment"
		)
		return new Tuple2(refId, stage)
	}

	private Tuple2<Integer, Stage> runTests(String text, String testName,
											int firstRefId) {
		int refId = firstRefId + 1
		Stage stage = new Stage(
			continuePipeline: false,
			failPipeline: true,
			job: "${SpinnakerDefaults.projectName(repository.name)}-test-env-${testName}",
			master: "my-jenkins-master",
			name: "${text}",
			parameters: [],
			refId: "${refId}",
			requisiteStageRefIds: [
				"${firstRefId}".toString()
			],
			type: "jenkins"
		)
		return new Tuple2(refId, stage)
	}

	private List<String> intToRange(int firstRefId, int lastRefId) {
		return (firstRefId..lastRefId).collect {
			"${it}".toString()
		}
	}

	private Trigger trigger() {
		return new Trigger(
			account: "demo-gcr-account",
			branch: "dev/.*",
			enabled: true,
			job: "spinnaker-github-webhook-pipeline-build",
			master: "my-jenkins-master",
			organization: "cf-spinnaker",
			payloadConstraints: new PayloadConstraints(),
			project: "marcingrzejszczak",
			registry: "gcr.io",
			repository: "cf-spinnaker/spin-kub-demo",
			slug: "github-webhook-kubernetes",
			source: "github",
			type: "jenkins"
		)
	}
}

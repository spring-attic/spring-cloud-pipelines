package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * A helper class to provide delegation for Closures. That way your IDE will help you in defining parameters.
 * Also it contains the default env vars setting
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class PipelineDefaults {

	final Map<String, String> defaultEnvVars
	final Map<String, String> variables

	PipelineDefaults(Map<String, String> variables) {
		this.defaultEnvVars = new HashMap<>(defaultEnvVars(variables))
		this.variables = variables
	}

	private Map<String, String> defaultEnvVars(Map<String, String> variables) {
		Map<String, String> envs = [:]
		setIfPresent(envs, variables, EnvironmentVariables.PROJECT_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PROJECT_TYPE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TYPE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.TOOLS_BRANCH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.M2_SETTINGS_REPO_ID_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.REPO_WITH_BINARIES_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.REPO_WITH_BINARIES_FOR_UPLOAD_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.REPO_WITH_BINARIES_CREDENTIAL_ID_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PIPELINE_DESCRIPTOR_ENV_VAR)
		// remove::start[CF]
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_ORG_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_SPACE_PREFIX_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_ORG_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_SPACE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_ORG_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_SPACE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_HOSTNAME_UUID_ENV_VAR)
		// remove::end[CF]
		// remove::start[K8S]
		setIfPresent(envs, variables, EnvironmentVariables.DOCKER_REGISTRY_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.DOCKER_REGISTRY_ORGANIZATION_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.DOCKER_REGISTRY_CREDENTIAL_ID_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.DOCKER_SERVER_ID_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.DOCKER_EMAIL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_API_URL_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CA_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CA_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CA_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CLIENT_CERT_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CLIENT_CERT_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CLIENT_CERT_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CLIENT_KEY_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CLIENT_KEY_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CLIENT_KEY_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CLIENT_TOKEN_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CLIENT_TOKEN_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CLIENT_TOKEN_PATH_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CLUSTER_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CLUSTER_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CLUSTER_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_CLUSTER_USERNAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_CLUSTER_USERNAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_CLUSTER_USERNAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_SYSTEM_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_SYSTEM_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_SYSTEM_NAME_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_TEST_NAMESPACE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_STAGE_NAMESPACE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.PAAS_PROD_NAMESPACE_ENV_VAR)
		setIfPresent(envs, variables, EnvironmentVariables.KUBERNETES_MINIKUBE_ENV_VAR)
		// remove::end[K8S]
		println "Will analyze the following variables passed to the seed job \n\n${variables}"
		println "Will set the following env vars to the generated jobs \n\n${envs}"
		return envs
	}

	private static void setIfPresent(Map<String, String> envs, Map<String, String> variables, String prop) {
		if (variables[prop]) {
			envs[prop] = variables[prop]
		}
	}

	void updateFromPipeline(PipelineDescriptor descriptor) {
		descriptor.pipeline.with {
			if (it.auto_prod != null)
				autoProd(it.auto_prod)
			if (it.auto_stage != null)
				autoStage(it.auto_stage)
			if (it.api_compatibility_step != null)
				apiCompatibilityStep(it.api_compatibility_step)
			if (it.rollback_step != null)
				rollbackStep(it.rollback_step)
			if (it.test_step != null)
				testStep(it.test_step)
			if (it.stage_step != null) {
				stageStep(it.stage_step)
			}
		}
	}

	void addEnvVar(String key, String value) {
		this.defaultEnvVars.put(key, value)
	}

	protected String prop(String key, String defaultValue = null) {
		return this.defaultEnvVars.get(key) != null ? this.defaultEnvVars.get(key) :
			this.variables.get(key) != null ? this.variables.get(key) : defaultValue
	}

	// Example of a version with date and time in the name
	String pipelineVersion() {
		return prop(EnvironmentVariables.PIPELINE_VERSION_ENV_VAR, '''1.0.0.M1-${GROOVY,script ="new Date().format('yyMMdd_HHmmss')"}-VERSION''')
	}

	String workspace() {
		return prop(EnvironmentVariables.WORKSPACE_ENV_VAR, ".")
	}

	String testModeDescriptor() {
		return prop(EnvironmentVariables.TEST_MODE_DESCRIPTOR_ENV_VAR, null)
	}

	String repoOrganization() {
		return prop(EnvironmentVariables.REPO_ORGANIZATION_ENV_VAR, "")
	}

	String repoManagement() {
		return prop(EnvironmentVariables.REPO_MANAGEMENT_TYPE_ENV_VAR, "")
	}

	String repoUrlRoot() {
		return prop(EnvironmentVariables.REPO_URL_ROOT_ENV_VAR, "")
	}

	String repoProjectsExcludePattern() {
		return prop(EnvironmentVariables.REPO_PROJECTS_EXCLUDE_PATTERN_ENV_VAR, "")
	}

	String pipelineDescriptor() {
		return prop(EnvironmentVariables.PIPELINE_DESCRIPTOR_ENV_VAR, "sc-pipelines.yml")
	}

	String cronValue() {
		return "H H * * 7" //every Sunday - I guess you should run it more often ;)
	}

// TODO: this doesn't scale too much
	String testReports() {
		return ["**/surefire-reports/*.xml", "**/test-results/**/*.xml"].join(",")
	}

	String gitCredentials() {
		return prop(EnvironmentVariables.GIT_CREDENTIAL_ID_ENV_VAR, "git")
	}

	String gitUsername() {
		return prop(EnvironmentVariables.GIT_USERNAME_ENV_VAR, "")
	}

	String gitPassword() {
		return prop(EnvironmentVariables.GIT_PASSWORD_ENV_VAR, "")
	}

	String gitToken() {
		return prop(EnvironmentVariables.GIT_TOKEN_ENV_VAR, "")
	}

	String gitSshCredentials() {
		return prop(EnvironmentVariables.GIT_SSH_CREDENTIAL_ID_ENV_VAR, "gitSsh")
	}

	boolean gitUseSshKey() {
		return prop(EnvironmentVariables.GIT_USE_SSH_ENV_VAR) == null ? false : Boolean.parseBoolean(prop("GIT_USE_SSH_KEY"))
	}

	String repoWithBinariesCredentials() {
		return prop(EnvironmentVariables.REPO_WITH_BINARIES_CREDENTIAL_ID_ENV_VAR, "")
	}

	String dockerCredentials() {
		return prop(EnvironmentVariables.DOCKER_REGISTRY_CREDENTIAL_ID_ENV_VAR, "")
	}

	String jdkVersion() { return prop(EnvironmentVariables.JDK_VERSION_ENV_VAR, "jdk8") }

// remove::start[CF]
	String cfTestCredentialId() {
		return prop(EnvironmentVariables.PAAS_TEST_CREDENTIAL_ID_ENV_VAR, "")
	}

	String cfTestOrg() {
		return prop(EnvironmentVariables.PAAS_TEST_ORG_ENV_VAR, "")
	}

	String cfTestSpacePrefix() {
		return prop(EnvironmentVariables.PAAS_TEST_SPACE_PREFIX_ENV_VAR, "")
	}

	String cfTestPassword() {
		return prop(EnvironmentVariables.PAAS_TEST_PASSWORD_ENV_VAR, "")
	}

	String cfStageUsername() {
		return prop(EnvironmentVariables.PAAS_STAGE_USERNAME_ENV_VAR, "")
	}

	String cfStagePassword() {
		return prop(EnvironmentVariables.PAAS_STAGE_PASSWORD_ENV_VAR, "")
	}

	String cfStageOrg() {
		return prop(EnvironmentVariables.PAAS_STAGE_ORG_ENV_VAR, "")
	}

	String cfStageSpace() {
		return prop(EnvironmentVariables.PAAS_STAGE_SPACE_ENV_VAR, "")
	}

	String cfStageCredentialId() {
		return prop(EnvironmentVariables.PAAS_STAGE_CREDENTIAL_ID_ENV_VAR, "")
	}

	String cfProdCredentialId() {
		return prop(EnvironmentVariables.PAAS_PROD_CREDENTIAL_ID_ENV_VAR, "")
	}

	String cfProdPassword() {
		return prop(EnvironmentVariables.PAAS_PROD_PASSWORD_ENV_VAR, "")
	}

	String cfProdUsername() {
		return prop(EnvironmentVariables.PAAS_PROD_USERNAME_ENV_VAR, "")
	}

	String cfProdOrg() {
		return prop(EnvironmentVariables.PAAS_PROD_ORG_ENV_VAR, "")
	}

	String cfProdSpace() {
		return prop(EnvironmentVariables.PAAS_PROD_SPACE_ENV_VAR, "")
	}
// remove::end[CF]
// remove::start[K8S]
	String k8sTestTokenCredentialId() {
		return prop(EnvironmentVariables.PAAS_TEST_CLIENT_TOKEN_ID_ENV_VAR, "")
	}

	String k8sStageTokenCredentialId() {
		return prop(EnvironmentVariables.PAAS_STAGE_CLIENT_TOKEN_ID_ENV_VAR, "")
	}

	String k8sProdTokenCredentialId() {
		return prop(EnvironmentVariables.PAAS_PROD_CLIENT_TOKEN_ID_ENV_VAR, "")
	}
// remove::end[K8S]
	String gitEmail() { return prop(EnvironmentVariables.GIT_EMAIL_ENV_VAR, "pivo@tal.com") }

	String gitName() { return prop(EnvironmentVariables.GIT_NAME_ENV_VAR, "Pivo Tal") }

	BashFunctions bashFunctions() {
		return new BashFunctions(gitName(), gitEmail(), gitUseSshKey())
	}

	boolean apiCompatibilityStep() {
		return prop(EnvironmentVariables.API_COMPATIBILITY_STEP_REQUIRED_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.API_COMPATIBILITY_STEP_REQUIRED_ENV_VAR) as String)
	}

	void apiCompatibilityStep(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.API_COMPATIBILITY_STEP_REQUIRED_ENV_VAR] = stepEnabled as String
	}

	boolean rollbackStep() {
		return prop(EnvironmentVariables.DB_ROLLBACK_STEP_REQUIRED_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.DB_ROLLBACK_STEP_REQUIRED_ENV_VAR))
	}

	void rollbackStep(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.DB_ROLLBACK_STEP_REQUIRED_ENV_VAR] = stepEnabled as String
	}

	boolean testStep() {
		return prop(EnvironmentVariables.DEPLOY_TO_TEST_STEP_REQUIRED_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.DEPLOY_TO_TEST_STEP_REQUIRED_ENV_VAR))
	}

	void testStep(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.DEPLOY_TO_TEST_STEP_REQUIRED_ENV_VAR] = stepEnabled as String
	}

	boolean stageStep() {
		return prop(EnvironmentVariables.DEPLOY_TO_STAGE_STEP_REQUIRED_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.DEPLOY_TO_STAGE_STEP_REQUIRED_ENV_VAR))
	}

	void stageStep(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.DEPLOY_TO_STAGE_STEP_REQUIRED_ENV_VAR] = stepEnabled as String
	}

	boolean autoStage() {
		return prop(EnvironmentVariables.AUTO_DEPLOY_TO_STAGE_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.AUTO_DEPLOY_TO_STAGE_ENV_VAR))
	}

	void autoStage(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.AUTO_DEPLOY_TO_STAGE_ENV_VAR] = stepEnabled as String
	}

	boolean autoProd() {
		return prop(EnvironmentVariables.AUTO_DEPLOY_TO_PROD_ENV_VAR) == null ? true : Boolean.parseBoolean(prop(EnvironmentVariables.AUTO_DEPLOY_TO_PROD_ENV_VAR))
	}

	void autoProd(boolean stepEnabled) {
		defaultEnvVars[EnvironmentVariables.AUTO_DEPLOY_TO_PROD_ENV_VAR] = stepEnabled as String
	}

// TODO: Automate customization of this value
	String toolsBranch() { return prop(EnvironmentVariables.TOOLS_BRANCH_ENV_VAR, "master") }

	String toolsRepo() {
		return prop(EnvironmentVariables.TOOLS_REPOSITORY_ENV_VAR, "https://github.com/spring-cloud/spring-cloud-pipelines/raw/${toolsBranch()}/dist/spring-cloud-pipelines.tar.gz")
	}

	RepoType repoType() { return RepoType.from(toolsRepo()) }
// TODO: K8S - consider parametrization
// remove::start[K8S]
	String mySqlRootCredential() {
		return prop(EnvironmentVariables.MYSQL_ROOT_CREDENTIAL_ID_ENV_VAR, "")
	}

	String mySqlCredential() {
		return prop(EnvironmentVariables.MYSQL_CREDENTIAL_ID_ENV_VAR, "")
	}
// remove::end[K8S]

// remove::start[SPINNAKER]
	String spinnakerTestDeploymentAccount() {
		return prop(EnvironmentVariables.SPINNAKER_TEST_DEPLOYMENT_ACCOUNT_ENV_VAR, "")
	}

	String spinnakerStageDeploymentAccount() {
		return prop(EnvironmentVariables.SPINNAKER_STAGE_DEPLOYMENT_ACCOUNT_ENV_VAR, "")
	}

	String spinnakerProdDeploymentAccount() {
		return prop(EnvironmentVariables.SPINNAKER_PROD_DEPLOYMENT_ACCOUNT_ENV_VAR, "")
	}

	String spinnakerJenkinsMaster() {
		return prop(EnvironmentVariables.SPINNAKER_JENKINS_MASTER_ENV_VAR, "")
	}

	String spinnakerTestHostname() {
		return prop(EnvironmentVariables.SPINNAKER_TEST_HOSTNAME_ENV_VAR, "")
	}

	String spinnakerStageHostname() {
		return prop(EnvironmentVariables.SPINNAKER_STAGE_HOSTNAME_ENV_VAR, "")
	}

	String spinnakerProdHostname() {
		return prop(EnvironmentVariables.SPINNAKER_PROD_HOSTNAME_ENV_VAR, "")
	}
// remove::end[SPINNAKER]
}

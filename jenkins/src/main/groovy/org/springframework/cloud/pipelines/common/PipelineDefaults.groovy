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

	public static final String GIT_USER_NAME_ENV_VAR = "GIT_USERNAME"
	public static final String GIT_PASSWORD_ENV_VAR = "GIT_PASSWORD"
	public static final String GIT_TOKEN_ENV_VAR = "GIT_TOKEN"

	final Map<String, String> defaultEnvVars
	final Map<String, String> variables

	PipelineDefaults(Map<String, String> variables) {
		this.defaultEnvVars = defaultEnvVars(variables)
		this.variables = variables
	}

	private Map<String, String> defaultEnvVars(Map<String, String> variables) {
		Map<String, String> envs = [:]
		setIfPresent(envs, variables, "PROJECT_NAME")
		setIfPresent(envs, variables, "PROJECT_TYPE")
		setIfPresent(envs, variables, "PAAS_TYPE")
		setIfPresent(envs, variables, "TOOLS_BRANCH")
		setIfPresent(envs, variables, "M2_SETTINGS_REPO_ID")
		setIfPresent(envs, variables, "REPO_WITH_BINARIES")
		setIfPresent(envs, variables, "REPO_WITH_BINARIES_FOR_UPLOAD")
		setIfPresent(envs, variables, "REPO_WITH_BINARIES_CREDENTIAL_ID")
		setIfPresent(envs, variables, "PIPELINE_DESCRIPTOR")
		// remove::start[CF]
		setIfPresent(envs, variables, "PAAS_TEST_API_URL")
		setIfPresent(envs, variables, "PAAS_STAGE_API_URL")
		setIfPresent(envs, variables, "PAAS_PROD_API_URL")
		setIfPresent(envs, variables, "PAAS_TEST_ORG")
		setIfPresent(envs, variables, "PAAS_TEST_SPACE_PREFIX")
		setIfPresent(envs, variables, "PAAS_STAGE_ORG")
		setIfPresent(envs, variables, "PAAS_STAGE_SPACE")
		setIfPresent(envs, variables, "PAAS_PROD_ORG")
		setIfPresent(envs, variables, "PAAS_PROD_SPACE")
		setIfPresent(envs, variables, "PAAS_HOSTNAME_UUID")
		setIfPresent(envs, variables, "JAVA_BUILDPACK_URL")
		// remove::end[CF]
		// remove::start[K8S]
		setIfPresent(envs, variables, "DOCKER_REGISTRY_URL")
		setIfPresent(envs, variables, "DOCKER_REGISTRY_ORGANIZATION")
		setIfPresent(envs, variables, "DOCKER_REGISTRY_CREDENTIAL_ID")
		setIfPresent(envs, variables, "DOCKER_SERVER_ID")
		setIfPresent(envs, variables, "DOCKER_EMAIL")
		setIfPresent(envs, variables, "PAAS_TEST_API_URL")
		setIfPresent(envs, variables, "PAAS_STAGE_API_URL")
		setIfPresent(envs, variables, "PAAS_PROD_API_URL")
		setIfPresent(envs, variables, "PAAS_TEST_CA_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CA_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CA_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_CERT_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_KEY_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_STAGE_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_PROD_CLIENT_TOKEN_PATH")
		setIfPresent(envs, variables, "PAAS_TEST_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_STAGE_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_PROD_CLUSTER_NAME")
		setIfPresent(envs, variables, "PAAS_TEST_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_STAGE_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_PROD_CLUSTER_USERNAME")
		setIfPresent(envs, variables, "PAAS_TEST_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_STAGE_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_PROD_SYSTEM_NAME")
		setIfPresent(envs, variables, "PAAS_TEST_NAMESPACE")
		setIfPresent(envs, variables, "PAAS_STAGE_NAMESPACE")
		setIfPresent(envs, variables, "PAAS_PROD_NAMESPACE")
		setIfPresent(envs, variables, "KUBERNETES_MINIKUBE")
		// remove::end[K8S]
		println "Will analyze the following variables psased to the seed job \n\n${variables}"
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
			if (it.stage_step != null) {
				stageStep(it.stage_step)
			}
		}
	}

	void addEnvVar(String key, String value) {
		this.defaultEnvVars.put(key, value)
	}

	protected String prop(String key, String defaultValue = null) {
		return this.defaultEnvVars.get(key) ?:
			this.variables.get(key) ?: defaultValue
	}

	// Example of a version with date and time in the name
	String pipelineVersion() {
		return prop("PIPELINE_VERSION", '''1.0.0.M1-${GROOVY,script ="new Date().format('yyMMdd_HHmmss')"}-VERSION''')
	}

	String pipelineDescriptor() {
		return prop("PIPELINE_DESCRIPTOR", "sc-pipelines.yml")
	}

	String cronValue() {
		return "H H * * 7" //every Sunday - I guess you should run it more often ;)
	}

// TODO: this doesn't scale too much
	String testReports() {
		return ["**/surefire-reports/*.xml", "**/test-results/**/*.xml"].join(",")
	}

	String gitCredentials() {
		return prop("GIT_CREDENTIAL_ID", "git")
	}

	String gitUsername() {
		return prop(GIT_USER_NAME_ENV_VAR, "")
	}

	String gitPassword() {
		return prop(GIT_PASSWORD_ENV_VAR, "")
	}

	String gitToken() {
		return prop("GIT_TOKEN_ID", "")
	}

	String gitSshCredentials() {
		return prop("GIT_SSH_CREDENTIAL_ID", "gitSsh")
	}

	boolean gitUseSshKey() {
		return prop("GIT_USE_SSH_KEY") == null ? false : Boolean.parseBoolean(prop("GIT_USE_SSH_KEY"))
	}

	String repoWithBinariesCredentials() {
		return prop("REPO_WITH_BINARIES_CREDENTIAL_ID", "")
	}

	String dockerCredentials() {
		return prop("DOCKER_REGISTRY_CREDENTIAL_ID", "")
	}

	String jdkVersion() { return prop("JDK_VERSION", "jdk8") }

// remove::start[CF]
	String cfTestCredentialId() {
		return prop("PAAS_TEST_CREDENTIAL_ID", "")
	}

	String cfStageCredentialId() {
		return prop("PAAS_STAGE_CREDENTIAL_ID", "")
	}
// remove::end[CF]
// remove::start[K8S]
	String k8sTestTokenCredentialId() {
		return prop("PAAS_TEST_CLIENT_TOKEN_ID", "")
	}

	String k8sStageTokenCredentialId() {
		return prop("PAAS_STAGE_CLIENT_TOKEN_ID", "")
	}
// remove::end[K8S]
	String gitEmail() { return prop("GIT_EMAIL", "pivo@tal.com") }

	String gitName() { return prop("GIT_NAME", "Pivo Tal") }

	BashFunctions bashFunctions() {
		return new BashFunctions(gitName(), gitEmail(), gitUseSshKey())
	}

	boolean apiCompatibilityStep() {
		return prop("API_COMPATIBILITY_STEP_REQUIRED") == null ? true : Boolean.parseBoolean(prop("API_COMPATIBILITY_STEP_REQUIRED") as String)
	}

	void apiCompatibilityStep(boolean stepEnabled) {
		defaultEnvVars["API_COMPATIBILITY_STEP_REQUIRED"] = stepEnabled as String
	}

	boolean rollbackStep() {
		return prop("DB_ROLLBACK_STEP_REQUIRED") == null ? true : Boolean.parseBoolean(prop("DB_ROLLBACK_STEP_REQUIRED"))
	}

	void rollbackStep(boolean stepEnabled) {
		defaultEnvVars["DB_ROLLBACK_STEP_REQUIRED"] = stepEnabled as String
	}

	boolean stageStep() {
		return prop("DEPLOY_TO_STAGE_STEP_REQUIRED") == null ? true : Boolean.parseBoolean(prop("DEPLOY_TO_STAGE_STEP_REQUIRED"))
	}

	void stageStep(boolean stepEnabled) {
		defaultEnvVars["DEPLOY_TO_STAGE_STEP_REQUIRED"] = stepEnabled as String
	}

	boolean autoStage() {
		return prop("AUTO_DEPLOY_TO_STAGE") == null ? true : Boolean.parseBoolean(prop("AUTO_DEPLOY_TO_STAGE"))
	}

	void autoStage(boolean stepEnabled) {
		defaultEnvVars["AUTO_DEPLOY_TO_STAGE"] = stepEnabled as String
	}

	boolean autoProd() {
		return prop("AUTO_DEPLOY_TO_PROD") == null ? true : Boolean.parseBoolean(prop("AUTO_DEPLOY_TO_PROD"))
	}

	void autoProd(boolean stepEnabled) {
		defaultEnvVars["AUTO_DEPLOY_TO_PROD"] = stepEnabled as String
	}

// TODO: Automate customization of this value
	String toolsBranch() { return prop("TOOLS_BRANCH", "master") }

	String toolsRepo() {
		return prop("TOOLS_REPOSITORY", "https://github.com/spring-cloud/spring-cloud-pipelines/raw/${toolsBranch()}/dist/spring-cloud-pipelines.tar.gz")
	}

	RepoType repoType() { return RepoType.from(toolsRepo()) }
// TODO: K8S - consider parametrization
// remove::start[K8S]
	String mySqlRootCredential() {
		return prop("MYSQL_ROOT_CREDENTIAL_ID", "")
	}

	String mySqlCredential() {
		return prop("MYSQL_CREDENTIAL_ID", "")
	}
// remove::end[K8S]
}

package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * Contains all Jenkins related environment variables
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
final class EnvironmentVariables {

	/**
	 * {@code GIT_CREDENTIAL_ID} - ID of credentials used for GIT interaction
	 */
	public static final String GIT_CREDENTIAL_ID_ENV_VAR = "GIT_CREDENTIAL_ID"

	/**
	 * {@code GIT_SSH_CREDENTIAL_ID} - ID of credentials used for GIT interaction via ssh
	 */
	public static final String GIT_SSH_CREDENTIAL_ID_ENV_VAR = "GIT_SSH_CREDENTIAL_ID"

	/**
	 * {@code GIT_USE_SSH} - if set to {@code true} will set the SSH key for GIT interaction
	 */
	public static final String GIT_USE_SSH_ENV_VAR = "GIT_USE_SSH"

	/**
	 * {@code GIT_USERNAME} - Username used for GIT integration
	 */
	public static final String GIT_USERNAME_ENV_VAR = "GIT_USERNAME"

	/**
	 * {@code GIT_PASSWORD} - Password used for GIT integration
	 */
	public static final String GIT_PASSWORD_ENV_VAR = "GIT_PASSWORD"

	/**
	 * {@code GIT_TOKEN} - Token used for GIT integration
	 */
	public static final String GIT_TOKEN_ENV_VAR = "GIT_TOKEN"

	/**
	 * {@code GIT_EMAIL} - Email used for GIT integration
	 */
	public static final String GIT_EMAIL_ENV_VAR = "GIT_EMAIL"

	/**
	 * {@code GIT_NAME} - Name used for GIT integration
	 */
	public static final String GIT_NAME_ENV_VAR = "GIT_NAME"

	/**
	 * {@code JDK_VERSION} - Name of the used JDK installation
	 */
	public static final String JDK_VERSION_ENV_VAR = "JDK_VERSION"

	/**
	 * {@code OUTPUT_FOLDER} - Folder to which the app will output files
	 */
	public static final String OUTPUT_FOLDER_ENV_VAR = "OUTPUT_FOLDER"

	// pipeline steps

	/**
	 * {@code API_COMPATIBILITY_STEP_REQUIRED} - Should API compatibility step be there? Defaults to {@code true}
	 */
	public static final String API_COMPATIBILITY_STEP_REQUIRED_ENV_VAR = "API_COMPATIBILITY_STEP_REQUIRED"

	/**
	 * {@code DB_ROLLBACK_STEP_REQUIRED} - Should DB rollback step be there? Defaults to {@code true}
	 */
	public static final String DB_ROLLBACK_STEP_REQUIRED_ENV_VAR = "DB_ROLLBACK_STEP_REQUIRED"

	/**
	 * {@code DEPLOY_TO_TEST_STEP_REQUIRED} - Should test steps be there? Defaults to {@code true}
	 */
	public static final String DEPLOY_TO_TEST_STEP_REQUIRED_ENV_VAR = "DEPLOY_TO_TEST_STEP_REQUIRED"

	/**
	 * {@code DEPLOY_TO_STAGE_STEP_REQUIRED} - Should stage steps be there? Defaults to {@code true}
	 */
	public static final String DEPLOY_TO_STAGE_STEP_REQUIRED_ENV_VAR = "DEPLOY_TO_STAGE_STEP_REQUIRED"

	/**
	 * {@code AUTO_DEPLOY_TO_STAGE} - Should deploy to stage automatically? Defaults to {@code true}
	 */
	public static final String AUTO_DEPLOY_TO_STAGE_ENV_VAR = "AUTO_DEPLOY_TO_STAGE"

	/**
	 * {@code AUTO_DEPLOY_TO_PROD} - Should deploy to prod automatically? Defaults to {@code true}
	 */
	public static final String AUTO_DEPLOY_TO_PROD_ENV_VAR = "AUTO_DEPLOY_TO_PROD"

	/**
	 * {@code PROJECT_NAME} - Project name that should override the default
	 * one (which is the one taken from the build)
	 */
	public static final String PROJECT_NAME_ENV_VAR = "PROJECT_NAME"

	/**
	 * {@code PROJECT_TYPE} - Type of the project. Depends on the used framework. Can be
	 * e.g. Maven, Gradle etc. Depending on the value of this env variable a proper
	 * {@code projectType/pipeline-$PROJECT_TYPE.sh } script will be sourced
	 */
	public static final String PROJECT_TYPE_ENV_VAR = "PROJECT_TYPE"

	/**
	 * {@code PAAS_TYPE} - Type of the used PAAS. Can be e.g. CF, K8S, etc.
	 * Depending on the value of this env variable a proper {@code pipeline-$PAAS_TYPE.sh }
	 * script will be sourced
	 */
	public static final String PAAS_TYPE_ENV_VAR = "PAAS_TYPE"

	/**
	 * {@code TOOLS_REPOSITORY} - URL of the tools repository (i.e. this repository) to be used within
	 * the build. Defaults to the tar.gz package of the master branch of the Spring Cloud Pipelines repo.
	 * You can provide URL to either tar.gz or .git repository.
	 */
	public static final String TOOLS_REPOSITORY_ENV_VAR = "TOOLS_REPOSITORY"

	/**
	 * {@code TOOLS_BRANCH} - Branch of tools (i.e. this repository) to be used within
	 * the build. Defaults to {@code master} but when you're working on a feature in
	 * Spring Cloud Pipelines you can want to point to your branch
	 */
	public static final String TOOLS_BRANCH_ENV_VAR = "TOOLS_BRANCH"

	/**
	 * {@code M2_SETTINGS_REPO_ID} - id of the credentials that will be put
	 * to {@code ~/.m2/settings.xml} as credentials used to deploy an artifact
	 */
	public static final String M2_SETTINGS_REPO_ID_ENV_VAR = "M2_SETTINGS_REPO_ID"

	/**
	 * {@code M2_SETTINGS_REPO_USERNAME} - username put inside {@code ~/.m2/settings.xml}
	 */
	public static final String M2_SETTINGS_REPO_USERNAME_ENV_VAR = "M2_SETTINGS_REPO_USERNAME"

	/**
	 * {@code M2_SETTINGS_REPO_PASSWORD} - password put inside {@code ~/.m2/settings.xml}
	 */
	public static final String M2_SETTINGS_REPO_PASSWORD_ENV_VAR = "M2_SETTINGS_REPO_PASSWORD"

	/**
	 * {@code REPO_WITH_BINARIES_CREDENTIAL_ID} - id of the credentials that will be
	 * passed to your build if you need to upload artifacts to a binary storage
	 */
	public static final String REPO_WITH_BINARIES_CREDENTIAL_ID_ENV_VAR = "REPO_WITH_BINARIES_CREDENTIAL_ID"

	/**
	 * {@code REPO_WITH_BINARIES} - URL of the repo that contains binaries
	 */
	public static final String REPO_WITH_BINARIES_ENV_VAR = "REPO_WITH_BINARIES"

	/**
	 * {@code REPO_WITH_BINARIES_FOR_UPLOAD} - URL for uploading of the repo that contains binaries.
	 * Often points to the {@code REPO_WITH_BINARIES}
	 */
	public static final String REPO_WITH_BINARIES_FOR_UPLOAD_ENV_VAR = "REPO_WITH_BINARIES_FOR_UPLOAD"

	/**
	 * {@code PIPELINE_DESCRIPTOR} - name of the pipeline descriptor. Defaults to
	 * {@code sc-pipelines.yml}
	 */
	public static final String PIPELINE_DESCRIPTOR_ENV_VAR = "PIPELINE_DESCRIPTOR"

	/**
	 * {@code PIPELINE_VERSION} - env var containing the version of the pipeline
	 */
	public static final String PIPELINE_VERSION_ENV_VAR = "PIPELINE_VERSION"

	/**
	 * {@code WORKSPACE} - env var containing the Jenkins workspace path
	 */
	public static final String WORKSPACE_ENV_VAR = "WORKSPACE"

	/**
	 * {@code TEST_MODE_DESCRIPTOR} - *used for tests* - descriptor to be returned
	 * for test purposes
	 */
	public static final String TEST_MODE_DESCRIPTOR_ENV_VAR = "TEST_MODE_DESCRIPTOR"

	// Tests

	/**
	 * {@code APPLICATION_URL} - used in integration tests. URL of the deployed application
	 */
	public static final String APPLICATION_URL_ENV_VAR = "APPLICATION_URL"


	/**
	 * {@code STUBRUNNER_URL} - used in integration tests. URL of the deployed
	 * Stub Runner application
	 */
	public static final String STUBRUNNER_URL_ENV_VAR = "STUBRUNNER_URL"

	/**
	 * {@code LATEST_PROD_VERSION} - used in rollback tests deployment and tests. Latest
	 * production version of the application.
	 */
	public static final String LATEST_PROD_VERSION_ENV_VAR = "LATEST_PROD_VERSION"

	/**
	 * {@code LATEST_PROD_TAG} - used in rollback tests deployment and tests. Latest
	 * production tag of the application.
	 */
	public static final String LATEST_PROD_TAG_ENV_VAR = "LATEST_PROD_TAG"

	/**
	 * {@code PASSED_LATEST_PROD_TAG} - used in rollback tests deployment and tests. Latest
	 * production tag of the application. Certain CI tools (e.g. Concourse)
	 * add the PASSED_ prefix before the env var.
	 */
	public static final String PASSED_LATEST_PROD_TAG_ENV_VAR = "PASSED_LATEST_PROD_TAG"

	// Project crawler

	/**
	 * {@code REPO_ORGANIZATION} - organization / team to crawl by project crawler
	 */
	public static final String REPO_ORGANIZATION_ENV_VAR = "REPO_ORGANIZATION"

	/**
	 * {@code REPO_MANAGEMENT_TYPE} - type of repo management used. Can be
	 * GITHUB, GITLAB, BITBUCKET or OTHER
	 */
	public static final String REPO_MANAGEMENT_TYPE_ENV_VAR = "REPO_MANAGEMENT_TYPE"

	/**
	 * {@code REPO_URL_ROOT} - URL of the API to reach to crawl the organization
	 */
	public static final String REPO_URL_ROOT_ENV_VAR = "REPO_URL_ROOT"

	/**
	 * {@code REPO_PROJECTS_EXCLUDE_PATTERN} - Pattern of projects to exclude
	 */
	public static final String REPO_PROJECTS_EXCLUDE_PATTERN_ENV_VAR = "REPO_PROJECTS_EXCLUDE_PATTERN"

	// COMMON for all PAASes
	/**
	 * {@code PAAS_TEST_API_URL} - URL of the test environment
	 */
	public static final String PAAS_TEST_API_URL_ENV_VAR = "PAAS_TEST_API_URL"

	/**
	 * {@code PAAS_STAGE_API_URL} - URL of the stage environment
	 */
	public static final String PAAS_STAGE_API_URL_ENV_VAR = "PAAS_STAGE_API_URL"

	/**
	 * {@code PAAS_PROD_API_URL} - URL of the prod environment
	 */
	public static final String PAAS_PROD_API_URL_ENV_VAR = "PAAS_PROD_API_URL"

	// remove::start[CF]
	/**
	 * {@code PAAS_TEST_CREDENTIAL_ID} - ID of credentials used to connect to test env
	 */
	public static final String PAAS_TEST_CREDENTIAL_ID_ENV_VAR = "PAAS_TEST_CREDENTIAL_ID"

	/**
	 * {@code PAAS_TEST_USERNAME} - Username used to connect to test env
	 */
	public static final String PAAS_TEST_USERNAME_ENV_VAR = "PAAS_TEST_USERNAME"

	/**
	 * {@code PAAS_TEST_PASSWORD} - Password used to connect to test env
	 */
	public static final String PAAS_TEST_PASSWORD_ENV_VAR = "PAAS_TEST_PASSWORD"

	/**
	 * {@code PAAS_STAGE_USERNAME} - Username used to connect to stage env
	 */
	public static final String PAAS_STAGE_USERNAME_ENV_VAR = "PAAS_STAGE_USERNAME"

	/**
	 * {@code PAAS_STAGE_PASSWORD} - Password used to connect to stage env
	 */
	public static final String PAAS_STAGE_PASSWORD_ENV_VAR = "PAAS_STAGE_PASSWORD"

	/**
	 * {@code PAAS_PROD_CREDENTIAL_ID} - ID of credentials used to connect to prod env
	 */
	public static final String PAAS_PROD_CREDENTIAL_ID_ENV_VAR = "PAAS_PROD_CREDENTIAL_ID"

	/**
	 * {@code PAAS_STAGE_CREDENTIAL_ID} - ID of credentials used to connect to stage env
	 */
	public static final String PAAS_STAGE_CREDENTIAL_ID_ENV_VAR = "PAAS_STAGE_CREDENTIAL_ID"

	/**
	 * {@code PAAS_PROD_USERNAME} - Username used to connect to prod env
	 */
	public static final String PAAS_PROD_USERNAME_ENV_VAR = "PAAS_PROD_USERNAME"

	/**
	 * {@code PAAS_PROD_PASSWORD} - Password used to connect to prod env
	 */
	public static final String PAAS_PROD_PASSWORD_ENV_VAR = "PAAS_PROD_PASSWORD"

	/**
	 * {@code PAAS_TEST_ORG} - Organization used for the test environment
	 */
	public static final String PAAS_TEST_ORG_ENV_VAR = "PAAS_TEST_ORG"

	/**
	 * {@code PAAS_TEST_SPACE_PREFIX} - Prefix prepended to the application name.
	 * Together forms a unique name of a test space.
	 */
	public static final String PAAS_TEST_SPACE_PREFIX_ENV_VAR = "PAAS_TEST_SPACE_PREFIX"

	/**
	 * {@code PAAS_STAGE_ORG} - Organization used for the stage environment
	 */
	public static final String PAAS_STAGE_ORG_ENV_VAR = "PAAS_STAGE_ORG"

	/**
	 * {@code PAAS_STAGE_SPACE} - Space used for the stage environment
	 */
	public static final String PAAS_STAGE_SPACE_ENV_VAR = "PAAS_STAGE_SPACE"

	/**
	 * {@code PAAS_PROD_ORG} - Organization used for the prod environment
	 */
	public static final String PAAS_PROD_ORG_ENV_VAR = "PAAS_PROD_ORG"

	/**
	 * {@code PAAS_PROD_SPACE} - Space used for the prod environment
	 */
	public static final String PAAS_PROD_SPACE_ENV_VAR = "PAAS_PROD_SPACE"

	/**
	 * {@code PAAS_HOSTNAME_UUID} - Hostname prepended to the route. When
	 * the name of the app is already taken, the route typically is also used.
	 * That's why you can use this env var to prepend additional value to the hostname
	 */
	public static final String PAAS_HOSTNAME_UUID_ENV_VAR = "PAAS_HOSTNAME_UUID"

	/**
	 * {@code CF_REDOWNLOAD_CLI} - defaults to true, forces to redownload CLI
	 * regardless of whether it's already downloaded or not
	 */
	public static final String CF_REDOWNLOAD_CLI_ENV_VAR = "CF_REDOWNLOAD_CLI"

	/**
	 * {@code CF_CLI_URL} - URL from which CF should be downloaded
	 */
	public static final String CF_CLI_URL_ENV_VAR = "CF_CLI_URL"

	/**
	 * {@code CF_SKIP_PREPARE_FOR_TESTS} - if true, will not connect to CF to fetch
	 * info about app host
	 */
	public static final String CF_SKIP_PREPARE_FOR_TESTS_ENV_VAR = "CF_SKIP_PREPARE_FOR_TESTS"


	// remove::end[CF]

	// remove::start[K8S]
	/**
	 * {@code DOCKER_REGISTRY_URL} - URL of the docker registry
	 */
	public static final String DOCKER_REGISTRY_URL_ENV_VAR = "DOCKER_REGISTRY_URL"

	/**
	 * {@code DOCKER_REGISTRY_ORGANIZATION} - Organization where your Docker repo lays
	 */
	public static final String DOCKER_REGISTRY_ORGANIZATION_ENV_VAR = "DOCKER_REGISTRY_ORGANIZATION"

	/**
	 * {@code DOCKER_REGISTRY_CREDENTIAL_ID} - ID of credentials used to push Docker images
	 */
	public static final String DOCKER_REGISTRY_CREDENTIAL_ID_ENV_VAR = "DOCKER_REGISTRY_CREDENTIAL_ID"

	/**
	 * {@code DOCKER_USERNAME} - Username used to push Docker images
	 */
	public static final String DOCKER_USERNAME_ENV_VAR = "DOCKER_USERNAME"

	/**
	 * {@code DOCKER_PASSWORD} - Password used to push Docker images
	 */
	public static final String DOCKER_PASSWORD_ENV_VAR = "DOCKER_PASSWORD"

	/**
	 * {@code DOCKER_SERVER_ID} - In {@code ~/.m2/settings.xml} server id of the Docker
	 * registry can be set so that credentials don't have to be explicitly passed
	 */
	public static final String DOCKER_SERVER_ID_ENV_VAR = "DOCKER_SERVER_ID"

	/**
	 * {@code DOCKER_EMAIL} - Email used for Docker repository interaction
	 */
	public static final String DOCKER_EMAIL_ENV_VAR = "DOCKER_EMAIL"

	/**
	 * {@code PAAS_TEST_CA_PATH} - Path to the test CA in the container
	 */
	public static final String PAAS_TEST_CA_PATH_ENV_VAR = "PAAS_TEST_CA_PATH"

	/**
	 * {@code PAAS_STAGE_CA_PATH} - Path to the stage CA in the container
	 */
	public static final String PAAS_STAGE_CA_PATH_ENV_VAR = "PAAS_STAGE_CA_PATH"

	/**
	 * {@code PAAS_PROD_CA_PATH} - Path to the prod CA in the container
	 */
	public static final String PAAS_PROD_CA_PATH_ENV_VAR = "PAAS_PROD_CA_PATH"

	/**
	 * {@code PAAS_TEST_CLIENT_CERT_PATH} - Path to the client certificate for test environment
	 */
	public static final String PAAS_TEST_CLIENT_CERT_PATH_ENV_VAR = "PAAS_TEST_CLIENT_CERT_PATH"

	/**
	 * {@code PAAS_STAGE_CLIENT_CERT_PATH} - Path to the client certificate for stage environment
	 */
	public static final String PAAS_STAGE_CLIENT_CERT_PATH_ENV_VAR = "PAAS_STAGE_CLIENT_CERT_PATH"

	/**
	 * {@code PAAS_PROD_CLIENT_CERT_PATH} - Path to the client certificate for prod environment
	 */
	public static final String PAAS_PROD_CLIENT_CERT_PATH_ENV_VAR = "PAAS_PROD_CLIENT_CERT_PATH"

	/**
	 * {@code PAAS_TEST_CLIENT_KEY_PATH} - Path to the client key for test environment
	 */
	public static final String PAAS_TEST_CLIENT_KEY_PATH_ENV_VAR = "PAAS_TEST_CLIENT_KEY_PATH"

	/**
	 * {@code PAAS_STAGE_CLIENT_KEY_PATH} - Path to the client key for stage environment
	 */
	public static final String PAAS_STAGE_CLIENT_KEY_PATH_ENV_VAR = "PAAS_STAGE_CLIENT_KEY_PATH"

	/**
	 * {@code PAAS_PROD_CLIENT_KEY_PATH} - Path to the client key for prod environment
	 */
	public static final String PAAS_PROD_CLIENT_KEY_PATH_ENV_VAR = "PAAS_PROD_CLIENT_KEY_PATH"

	/**
	 * {@code TOKEN} - Token used to login to PAAS
	 */
	public static final String TOKEN_ENV_VAR = "TOKEN"

	/**
	 * {@code PAAS_TEST_CLIENT_TOKEN_PATH} - Path to the file containing the token for test env
	 */
	public static final String PAAS_TEST_CLIENT_TOKEN_PATH_ENV_VAR = "PAAS_TEST_CLIENT_TOKEN_PATH"

	/**
	 * {@code PAAS_STAGE_CLIENT_TOKEN_PATH} - Path to the file containing the token for stage env
	 */
	public static final String PAAS_STAGE_CLIENT_TOKEN_PATH_ENV_VAR = "PAAS_STAGE_CLIENT_TOKEN_PATH"

	/**
	 * {@code PAAS_PROD_CLIENT_TOKEN_PATH} - Path to the file containing the token for prod env
	 */
	public static final String PAAS_PROD_CLIENT_TOKEN_PATH_ENV_VAR = "PAAS_PROD_CLIENT_TOKEN_PATH"

	/**
	 * {@code PAAS_TEST_CLIENT_TOKEN_ID} - ID of the token used to connect to test environment
	 */
	public static final String PAAS_TEST_CLIENT_TOKEN_ID_ENV_VAR = "PAAS_TEST_CLIENT_TOKEN_ID"

	/**
	 * {@code PAAS_STAGE_CLIENT_TOKEN_ID} - ID of the token used to connect to stage environment
	 */
	public static final String PAAS_STAGE_CLIENT_TOKEN_ID_ENV_VAR = "PAAS_STAGE_CLIENT_TOKEN_ID"

	/**
	 * {@code PAAS_PROD_CLIENT_TOKEN_ID} - ID of the token used to connect to prod environment
	 */
	public static final String PAAS_PROD_CLIENT_TOKEN_ID_ENV_VAR = "PAAS_PROD_CLIENT_TOKEN_ID"

	/**
	 * {@code PAAS_TEST_CLUSTER_NAME_ENV_VAR} - Name of the cluster for test env
	 */
	public static final String PAAS_TEST_CLUSTER_NAME_ENV_VAR = "PAAS_TEST_CLUSTER_NAME"

	/**
	 * {@code PAAS_STAGE_CLUSTER_NAME} - Name of the cluster for stage env
	 */
	public static final String PAAS_STAGE_CLUSTER_NAME_ENV_VAR = "PAAS_STAGE_CLUSTER_NAME"

	/**
	 * {@code PAAS_PROD_CLUSTER_NAME} - Name of the cluster for prod env
	 */
	public static final String PAAS_PROD_CLUSTER_NAME_ENV_VAR = "PAAS_PROD_CLUSTER_NAME"

	/**
	 * {@code PAAS_TEST_CLUSTER_USERNAME} - Name of the user to connect to test environment
	 */
	public static final String PAAS_TEST_CLUSTER_USERNAME_ENV_VAR = "PAAS_TEST_CLUSTER_USERNAME"

	/**
	 * {@code PAAS_STAGE_CLUSTER_USERNAME} - Name of the user to connect to stage environment
	 */
	public static final String PAAS_STAGE_CLUSTER_USERNAME_ENV_VAR = "PAAS_STAGE_CLUSTER_USERNAME"

	/**
	 * {@code PAAS_PROD_CLUSTER_USERNAME} - Name of the user to connect to prod environment
	 */
	public static final String PAAS_PROD_CLUSTER_USERNAME_ENV_VAR = "PAAS_PROD_CLUSTER_USERNAME"

	/**
	 * {@code PAAS_TEST_SYSTEM_NAME} - Name of the system for test env
	 */
	public static final String PAAS_TEST_SYSTEM_NAME_ENV_VAR = "PAAS_TEST_SYSTEM_NAME"

	/**
	 * {@code PAAS_STAGE_SYSTEM_NAME} - Name of the system for stage env
	 */
	public static final String PAAS_STAGE_SYSTEM_NAME_ENV_VAR = "PAAS_STAGE_SYSTEM_NAME"

	/**
	 * {@code PAAS_PROD_SYSTEM_NAME} - Name of the system for prod env
	 */
	public static final String PAAS_PROD_SYSTEM_NAME_ENV_VAR = "PAAS_PROD_SYSTEM_NAME"

	/**
	 * {@code PAAS_TEST_NAMESPACE} - Namespace used for the test env
	 */
	public static final String PAAS_TEST_NAMESPACE_ENV_VAR = "PAAS_TEST_NAMESPACE"

	/**
	 * {@code PAAS_STAGE_NAMESPACE} - Namespace used for the stage env
	 */
	public static final String PAAS_STAGE_NAMESPACE_ENV_VAR = "PAAS_STAGE_NAMESPACE"

	/**
	 * {@code PAAS_PROD_NAMESPACE} - Namespace used for the prod env
	 */
	public static final String PAAS_PROD_NAMESPACE_ENV_VAR = "PAAS_PROD_NAMESPACE"

	/**
	 * {@code KUBERNETES_MINIKUBE} - set to {@code true} if minikube is used
	 */
	public static final String KUBERNETES_MINIKUBE_ENV_VAR = "KUBERNETES_MINIKUBE"

	/**
	 * {@code MYSQL_ROOT_CREDENTIAL_ID} - ID of the MYSQL ROOT user credentials
	 */
	public static final String MYSQL_ROOT_CREDENTIAL_ID_ENV_VAR = "MYSQL_ROOT_CREDENTIAL_ID"

	/**
	 * {@code MYSQL_ROOT_USER} - Username of the MYSQL user
	 */
	public static final String MYSQL_ROOT_USER_ENV_VAR = "MYSQL_ROOT_USER"

	/**
	 * {@code MYSQL_CREDENTIAL_ID} - ID of the MYSQL user credentials
	 */
	public static final String MYSQL_CREDENTIAL_ID_ENV_VAR = "MYSQL_CREDENTIAL_ID"

	/**
	 * {@code MYSQL_USER} - Username of the MYSQL user
	 */
	public static final String MYSQL_USER_ENV_VAR = "MYSQL_USER"

	// remove::end[K8S]

	// remove::start[SPINNAKER]
	/**
	 * {@code SPINNAKER_TEST_DEPLOYMENT_ACCOUNT} - Account used for deployment to test env
	 */
	public static final String SPINNAKER_TEST_DEPLOYMENT_ACCOUNT_ENV_VAR = "SPINNAKER_TEST_DEPLOYMENT_ACCOUNT"

	/**
	 * {@code SPINNAKER_STAGE_DEPLOYMENT_ACCOUNT} - Account used for deployment to stage env
	 */
	public static final String SPINNAKER_STAGE_DEPLOYMENT_ACCOUNT_ENV_VAR = "SPINNAKER_STAGE_DEPLOYMENT_ACCOUNT"

	/**
	 * {@code SPINNAKER_PROD_DEPLOYMENT_ACCOUNT} - Account used for deployment to prod env
	 */
	public static final String SPINNAKER_PROD_DEPLOYMENT_ACCOUNT_ENV_VAR = "SPINNAKER_PROD_DEPLOYMENT_ACCOUNT"

	/**
	 * {@code SPINNAKER_JENKINS_ROOT_URL} - name of the Jenkins host used by Spinnaker
	 */
	public static final String SPINNAKER_JENKINS_ROOT_URL_ENV_VAR = "SPINNAKER_JENKINS_ROOT_URL"

	/**
	 * {@code SPINNAKER_JENKINS_ACCOUNT} - name of the Jenkins account used by Spinnaker
	 */
	public static final String SPINNAKER_JENKINS_ACCOUNT_ENV_VAR = "SPINNAKER_JENKINS_ACCOUNT"

	/**
	 * {@code SPINNAKER_JENKINS_MASTER} - name of the Jenkins master installation
	 */
	public static final String SPINNAKER_JENKINS_MASTER_ENV_VAR = "SPINNAKER_JENKINS_MASTER"

	/**
	 * {@code SPINNAKER_TEST_HOSTNAME} - the hostname appended to the routes for test envs
	 */
	public static final String SPINNAKER_TEST_HOSTNAME_ENV_VAR = "SPINNAKER_TEST_HOSTNAME"

	/**
	 * {@code SPINNAKER_STAGE_HOSTNAME} - the hostname appended to the routes for test envs
	 */
	public static final String SPINNAKER_STAGE_HOSTNAME_ENV_VAR = "SPINNAKER_STAGE_HOSTNAME"

	/**
	 * {@code SPINNAKER_PROD_HOSTNAME} - the hostname appended to the routes for test envs
	 */
	public static final String SPINNAKER_PROD_HOSTNAME_ENV_VAR = "SPINNAKER_PROD_HOSTNAME"
	// remove::end[SPINNAKER]
}

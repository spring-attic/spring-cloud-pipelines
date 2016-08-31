package io.springframework.cloud.common

import io.springframework.common.BuildAndDeploy
/**
 * @author Marcin Grzejszczak
 */
trait SpringCloudJobs extends BuildAndDeploy {

	@Override
	String projectSuffix() {
		return 'spring-cloud'
	}

	String cleanup() {
		return '''
					echo "Clearing the installed cloud artifacts"
					rm -rf ~/.m2/repository/org/springframework/cloud/
					rm -rf ~/.gradle/caches/modules-2/files-2.1/org.springframework.cloud/
					'''
	}
	
	String setupGitCredentials() {
		return """
					set +x
					git config user.name "${githubUserName()}"
					git config user.email "${githubEmail()}"
					git config credential.helper "store --file=/tmp/gitcredentials"
					echo "https://\$${githubRepoUserNameEnvVar()}:\$${githubRepoPasswordEnvVar()}@github.com" > /tmp/gitcredentials
					set -x
				"""
	} 

	String buildDocsWithGhPages() {
		return """#!/bin/bash -x
					export MAVEN_PATH=${mavenBin()}
					${setupGitCredentials()}
					${buildDocs()}
					echo "Downloading ghpages script from Spring Cloud Build"
					mkdir -p target
					rm -rf target/ghpages.sh
					curl https://raw.githubusercontent.com/spring-cloud/spring-cloud-build/master/docs/src/main/asciidoc/ghpages.sh -o target/ghpages.sh
					chmod +x target/ghpages.sh
					. ./target/ghpages.sh
					${cleanGitCredentials()}
					"""
	}

	/**
	 * Dirty hack cause Jenkins is not inserting Maven to path...
	 * Requires using Maven3 installation before calling
	 */
	String mavenBin() {
		return "/opt/jenkins/data/tools/hudson.tasks.Maven_MavenInstallation/maven33/apache-maven-3.3.9/bin/"
	}

	String cleanGitCredentials() {
		return "rm -rf /tmp/gitcredentials"
	}

	String buildDocs() {
		return '''./mvnw clean install -P docs -q -U -DskipTests=true -Dmaven.test.redirectTestOutputToFile=true'''
	}

	String repoUserNameEnvVar() {
		return 'REPO_USERNAME'
	}

	String repoPasswordEnvVar() {
		return 'REPO_PASSWORD'
	}

	String githubRepoUserNameEnvVar() {
		return 'GITHUB_REPO_USERNAME'
	}

	String githubRepoPasswordEnvVar() {
		return 'GITHUB_REPO_PASSWORD'
	}

	String repoSpringIoUserCredentialId() {
		return '02bd1690-b54f-4c9f-819d-a77cb7a9822c'
	}

	String githubUserCredentialId() {
		return '3a20bcaa-d8ad-48e3-901d-9fbc941376ee'
	}

	String githubUserName() {
		return 'spring-buildmaster'
	}

	String githubEmail() {
		return 'buildmaster@springframework.org'
	}

}
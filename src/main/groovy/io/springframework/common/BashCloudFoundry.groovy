package io.springframework.common

/**
 * @author Marcin Grzejszczak
 */
trait BashCloudFoundry {

	String cfUsername() {
		return '$CF_USERNAME'
	}

	String cfPassword() {
		return '$CF_PASSWORD'
	}

	String cfSpace() {
		return '$CF_SPACE'
	}

	String cfScriptToExecute(String script) {
		return """
						echo "Downloading Cloud Foundry"
						curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx

						echo "Setting alias to cf"
						alias cf=`pwd`/cf
						export cf=`pwd`/cf

						echo "Cloud foundry version"
						cf --version

						echo "Logging in to CF"
						cf api --skip-ssl-validation api.run.pivotal.io
						cf login -u ${cfUsername()} -p ${cfPassword()} -o FrameworksAndRuntimes -s ${cfSpace()}

						echo "Running script CF"
						bash ${script}
					"""
	}

}
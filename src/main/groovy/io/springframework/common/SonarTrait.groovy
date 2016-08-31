package io.springframework.common

/**
 * Trait with Sonar related code
 *
 * @author Marcin Grzejszczak
 */
trait SonarTrait {
	void appendSonar(Node rootNode) {
		Node propertiesNode = rootNode / 'buildWrappers'
		propertiesNode / 'hudson.plugins.sonar.SonarBuildWrapper'
	}
}

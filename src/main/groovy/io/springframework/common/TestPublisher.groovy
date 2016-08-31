package io.springframework.common

/**
 * Contains default patterns for JUnit results
 *
 * @author Marcin Grzejszczak
 */
trait TestPublisher {
	String mavenJUnitResults() {
		return '**/surefire-reports/*.xml'
	}

	String mavenJUnitFailsafeResults() {
		return '**/failsafe-reports/*.xml'
	}

	String gradleJUnitResults() {
		return '**/test-results/**/*.xml'
	}
}

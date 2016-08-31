package io.springframework.cloud.common

/**
 *
 * @author Marcin Grzejszczak
 */
trait SpringCloudNotification {

	String cloudRoom() {
		return "spring-cloud-firehose"
	}
}

package io.springframework.springboot.common

/**
 * A trait to append notifications to Slack
 *
 * @author Marcin Grzejszczak
 */
trait SpringBootNotification {

	String bootRoom() {
		return 'spring-firehose'
	}

}

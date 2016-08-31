package io.springframework.springio.common
/**
 * A trait to append notifications to Slack
 *
 * @author Marcin Grzejszczak
 */
trait SpringIoNotification {

	String springRoom() {
		return "spring-firehose"
	}

}

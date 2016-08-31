package io.springframework.common

import groovy.transform.CompileStatic

/**
 * Contains common cron expressions
 *
 * @author Marcin Grzejszczak
 */
@CompileStatic
trait Cron {

	String oncePerDay() {
		return "H H * * *"
	}

	String everySunday() {
		return "H H * * 7"
	}

	String everyThreeHours() {
		return "H H/3 * * *"
	}

	String everyDatAtFullHour(int hour) {
		return "H H $hour 1/1 * ? *"
	}

	String everySixHours() {
		return "H H/6 * * *"
	}
}
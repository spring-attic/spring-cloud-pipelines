package org.springframework.cloud.pipelines.common

import javaposse.jobdsl.dsl.jobs.FreeStyleJob

/**
 * Test implementation of {@link JobCustomizer} that marks
 * a method implemented
 *
 * @author Marcin Grzejszczak
 */
class TestJobCustomizer implements JobCustomizer {

	public static boolean EXECUTED_ALL = false
	public static boolean EXECUTED_BUILD = false
	public static boolean EXECUTED_TEST = false
	public static boolean EXECUTED_STAGE = false
	public static boolean EXECUTED_PROD = false

	@Override
	void customizeAll(FreeStyleJob job) {
		EXECUTED_ALL = true
	}

	@Override
	void customizeBuild(FreeStyleJob job) {
		EXECUTED_BUILD = true
	}

	@Override
	void customizeTest(FreeStyleJob job) {
		EXECUTED_TEST = true
	}

	@Override
	void customizeStage(FreeStyleJob job) {
		EXECUTED_STAGE = true
	}

	@Override
	void customizeProd(FreeStyleJob job) {
		EXECUTED_PROD = true
	}
}

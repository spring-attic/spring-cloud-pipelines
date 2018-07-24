package org.springframework.cloud.pipelines.common

import groovy.transform.CompileStatic

/**
 * Knows whether given stage should be enabled or automatic basing on values
 * from the descriptor or environment variables
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class StepEnabledChecker {
	
	private final PipelineDescriptor descriptor
	private final PipelineDefaults defaults

	StepEnabledChecker(PipelineDescriptor descriptor, PipelineDefaults defaults) {
		this.descriptor = descriptor
		this.defaults = defaults
	}

	boolean autoProdSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.auto_prod, defaults.autoProd())
	}

	boolean apiCompatibilityStepSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.api_compatibility_step, defaults.apiCompatibilityStep())
	}

	boolean stageStepSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.stage_step, defaults.stageStep())
	}

	boolean stageStepMissing() {
		return !stageStepSet()
	}

	boolean autoStageSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.auto_stage, defaults.autoStage())
	}

	boolean rollbackStepSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.rollback_step,
			defaults.rollbackStep()) && testStepSet()
	}

	boolean rollbackStepMissing() {
		return !rollbackStepSet()
	}

	boolean testStepSet() {
		return valueOrDefaultIfNull(descriptor.pipeline.test_step, defaults.testStep())
	}

	boolean testStepMissing() {
		return !testStepSet()
	}

	private boolean valueOrDefaultIfNull(Boolean value, boolean defaultValue) {
		return value == null ? defaultValue : value
	}
}

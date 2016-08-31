package io.springframework.common

/**
 * @author Marcin Grzejszczak
 */
trait Pipeline {
	Closure defaultDeliveryPipelineVersion() {
		return {
			deliveryPipelineVersion('BUILD-${BUILD_NUMBER}', true)
		}
	}
}
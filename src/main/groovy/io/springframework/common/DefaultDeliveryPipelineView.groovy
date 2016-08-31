package io.springframework.common

import javaposse.jobdsl.dsl.views.NestedViewsContext
/**
 * @author Marcin Grzejszczak
 */
class DefaultDeliveryPipelineView {

	static void build(NestedViewsContext nestedViewsContext, String pipelineName, String description, String firstJob) {
		nestedViewsContext.deliveryPipelineView(pipelineName) {
			allowPipelineStart()
			pipelineInstances(5)
			showAggregatedPipeline(false)
			columns(1)
			updateInterval(5)
			enableManualTriggers()
			showAvatars()
			showChangeLog()
			pipelines {
				component(description, firstJob)
			}
			allowRebuild()
			showDescription()
			showPromotions()
			showTotalBuildTime()
			configure {
				(it / 'showTestResults').setValue(true)
				(it / 'pagingEnabled').setValue(true)
			}
		}
	}
}

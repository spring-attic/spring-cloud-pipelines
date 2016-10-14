import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

['github-analytics','github-webhook'].each {
	String projectName = "${it}-pipeline"
	dsl.deliveryPipelineView(projectName) {
		allowPipelineStart()
		pipelineInstances(5)
		showAggregatedPipeline(false)
		columns(1)
		updateInterval(5)
		enableManualTriggers()
		showAvatars()
		showChangeLog()
		pipelines {
			component("Deployment", "${projectName}-build")
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

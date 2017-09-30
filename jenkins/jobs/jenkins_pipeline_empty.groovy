import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

String projectName = 'jenkins-pipeline-empty'

dsl.job("${projectName}-build") {
	deliveryPipelineConfiguration('Build', 'Build and Upload')
	wrappers {
		deliveryPipelineVersion('BUILD-${BUILD_NUMBER}', true)
	}
	steps {
		shell("echo 'Building and publishing'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-build-api-check") {
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-build-api-check") {
	deliveryPipelineConfiguration('Build', 'API compatibility check')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Running API compatibility check'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-deploy") {
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-test-env-deploy") {
	deliveryPipelineConfiguration('Test', 'Deploy to test')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Deploying to test env'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-test") {
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-test-env-test") {
	deliveryPipelineConfiguration('Test', 'Tests on test')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Running tests on test env'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-rollback-deploy") {
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-test-env-rollback-deploy") {
	deliveryPipelineConfiguration('Test', 'Deploy to test latest prod version')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Deploying to test env previous prod version'")
	}
	publishers {
		downstreamParameterized {
			trigger("${projectName}-test-env-rollback-test") {
				triggerWithNoParameters()
			}
		}
	}
}

dsl.job("${projectName}-test-env-rollback-test") {
	deliveryPipelineConfiguration('Test', 'Tests on test latest prod version')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Running tests on test env with latest prod version'")
	}
	publishers {
		buildPipelineTrigger("${projectName}-stage-env-deploy") {
			parameters {
				currentBuild()
			}
		}
	}
}

dsl.job("${projectName}-stage-env-deploy") {
	deliveryPipelineConfiguration('Stage', 'Deploy to stage')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Deploying to stage env'")
	}
	publishers {
		buildPipelineTrigger("${projectName}-stage-env-test") {
			parameters {
				currentBuild()
			}
		}
	}
}

dsl.job("${projectName}-stage-env-test") {
	deliveryPipelineConfiguration('Stage', 'End to end tests on stage')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Running tests on stage env'")
	}
	publishers {
		buildPipelineTrigger("${projectName}-prod-env-deploy") {
			parameters {
				currentBuild()
			}
		}
		buildPipelineTrigger("${projectName}-prod-env-rollback") {
			parameters {
				currentBuild()
			}
		}
	}
}

dsl.job("${projectName}-prod-env-deploy") {
	deliveryPipelineConfiguration('Prod', 'Deploy to prod')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Deploying to prod env'")
	}
	publishers {
		buildPipelineTrigger("${projectName}-prod-env-complete,${projectName}-prod-env-rollback") {
			parameters {
				currentBuild()
			}
		}
	}
}

dsl.job("${projectName}-prod-env-rollback") {
	deliveryPipelineConfiguration('Prod', 'Rollback to blue')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Rolling back to green'")
	}
}

dsl.job("${projectName}-prod-env-complete") {
	deliveryPipelineConfiguration('Prod', 'Complete switch over')
	wrappers {
		deliveryPipelineVersion('${ENV,var="PIPELINE_VERSION"}', true)
	}
	steps {
		shell("echo 'Disabling blue instance'")
	}
}

dsl.deliveryPipelineView("${projectName}-pipeline") {
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

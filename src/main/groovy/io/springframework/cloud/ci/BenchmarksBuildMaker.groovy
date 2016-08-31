package io.springframework.cloud.ci

import io.springframework.cloud.common.SpringCloudNotification
import io.springframework.common.Cron
import io.springframework.common.JdkConfig
import io.springframework.common.SlackPlugin
import javaposse.jobdsl.dsl.DslFactory
/**
 * @author Marcin Grzejszczak
 */
class BenchmarksBuildMaker implements SpringCloudNotification, JdkConfig, Cron {
	private final DslFactory dsl

	BenchmarksBuildMaker(DslFactory dsl) {
		this.dsl = dsl
	}

	void buildSleuth() {
		buildSleuth(oncePerDay())
	}

	void buildSleuth(String cronExpr) {
		dsl.job('spring-cloud-sleuth-benchmark-ci') {
			triggers {
				cron cronExpr
			}
			scm {
				git {
					remote {
						url "https://github.com/spring-cloud/spring-cloud-sleuth"
						branch 'master'
					}
				}
			}
			jdk jdk8()
			steps {
				shell('''
				echo "Running JMeter benchmarks"
				./scripts/runJmeterBenchmarks.sh
				''')
				shell('''
				echo "Copying JMeter results"
				mkdir -p results/benchmarks
				cp -avr benchmarks/target/ results/benchmarks/
				''')
				shell('''
				echo "Running JMH benchmark tests"
				./scripts/runJmhBenchmarks.sh
				''')
				shell('''
				echo "Copying Benchmarks results"
				mkdir -p results/jmh
				cp -avr target/ results/jmh/
				''')
			}
			publishers {
				archiveArtifacts('results/benchmarks/target/jmeter/results/*.png')
				archiveArtifacts('results/benchmarks/target/jmeter/results/analysis/*.*')
				archiveArtifacts('results/jmh/target/benchmarks.log')
			}
			configure {
				SlackPlugin.slackNotification(it as Node) {
					room(cloudRoom())
				}
				appendPerformancePlugin(it as Node,
						'results/benchmarks/target/jmeter/results/*.jtl')
			}
		}
	}

	private void appendPerformancePlugin(Node rootNode, String jmeterPath) {
		Node propertiesNode = rootNode / 'publishers'
		def perf = propertiesNode / 'hudson.plugins.performance.PerformancePublisher'
		(perf / 'errorFailedThreshold').setValue(0)
		(perf / 'errorUnstableThreshold').setValue(0)
		(perf / 'errorUnstableResponseTimeThreshold').setValue(0)
		(perf / 'relativeFailedThresholdPositive').setValue(0)
		(perf / 'relativeFailedThresholdNegative').setValue(0)
		(perf / 'relativeUnstableThresholdPositive').setValue(0)
		(perf / 'relativeUnstableThresholdNegative').setValue(0)
		(perf / 'nthBuildNumber').setValue(0)
		(perf / 'modeRelativeThresholds').setValue(false)
		(perf / 'configType').setValue('ART')
		(perf / 'modeOfThreshold').setValue(false)
		(perf / 'compareBuildPrevious').setValue(false)
		(perf / 'xml').setValue('')
		(perf / 'modePerformancePerTestCase').setValue(true)
		(perf / 'modeThroughput').setValue(false)
		def parsers = perf / 'parsers'
		if (jmeterPath) {
			(parsers / 'hudson.plugins.performance.JMeterParser' / 'glob').setValue(jmeterPath)
		}
		/*if (junitPath) {
			(parsers / 'hudson.plugins.performance.JUnitParser' / 'glob').setValue(junitPath)
		}*/
	}
}

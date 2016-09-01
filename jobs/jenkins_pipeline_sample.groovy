import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

dsl.job('jenkins-pipeline-sample') {
	steps {
		shell("echo 'HELLO'")
	}
}

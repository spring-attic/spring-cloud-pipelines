import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

dsl.job('jenkins-pipeline-empty') {
	steps {
		shell("echo 'HELLO'")
	}
}

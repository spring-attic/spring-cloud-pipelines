import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

dsl.pipelineJob('jenkins-pipeline-jenkinsfile-empty') {
	definition {
		cps {
			script("""
			node {
				stage 'Build and Upload'
				echo 'Building and Deploying'

				stage 'Deploy to test'
				echo 'Deploying to test'
				stage 'Tests on test'
				echo 'Running tests on test'

				stage 'Deploy to stage'
				echo 'Deploying to stage'
				stage 'Tests on stage'
				echo 'Running tests on stage'

				stage 'Deploy to prod'
				echo 'Deploying to prod green instance'
				stage 'Complete switch over'
				echo 'Disabling blue instance'
			}
			""")
		}
	}
}

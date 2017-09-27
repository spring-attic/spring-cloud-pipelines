import javaposse.jobdsl.dsl.DslFactory

DslFactory dsl = this

dsl.pipelineJob('jenkins-pipeline-jenkinsfile-empty') {
	definition {
		cps {
			script("""
			node {
				stage 'Build and Upload'
				echo 'Building and Deploying'
				stage 'API compatibility check'
				echo 'Running API compatibility check'

				stage 'Deploy to test'
				echo 'Deploying to test'
				stage 'Tests on test'
				echo 'Running tests on test'
				stage 'Deploy to test latest prod version'
				echo 'Deploying to test latest prod version'
				stage 'Tests on test latest prod version'
				echo 'Running tests on test with latest prod version'

				stage 'Deploy to stage'
				echo 'Deploying to stage'
				stage 'End to end tests on stage'
				echo 'Running end to end tests on stage'

				stage 'Deploy to prod'
				echo 'Deploying to prod green instance'
				stage 'Complete switch over'
				echo 'Disabling blue instance'
			}
			""")
		}
	}
}


job('spring-io-seed') {
    scm {
        git {
            remote {
                github('marcingrzejszczak/jenkins-pipeline')
            }
			branch('master')
            createTag(false)
        }
    }
    steps {
        gradle("clean build")
        dsl {
            external('jobs/springboot/*.groovy')
            removeAction('DISABLE')
            removeViewAction('DELETE')
            ignoreExisting(false)
            additionalClasspath([
                'src/main/groovy', 'src/main/resources'
            ].join("\n"))
        }
    }
}

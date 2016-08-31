
job('jenkins-pipeline-seed') {
    scm {
        git {
            remote {
                github('marcingrzejszczak/jenkins-pipeline')
            }
			branch('wip')
            createTag(false)
        }
    }
    steps {
        gradle("clean build")
        dsl {
            external('jobs/*.groovy')
            removeAction('DISABLE')
            removeViewAction('DELETE')
            ignoreExisting(false)
            additionalClasspath([
                'src/main/groovy', 'src/main/resources'
            ].join("\n"))
        }
    }
}

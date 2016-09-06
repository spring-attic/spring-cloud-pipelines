import javaposse.jobdsl.dsl.DslFactory

DslFactory factory = this

factory.job('jenkins-pipeline-seed') {
    scm {
        git {
            remote {
                github('marcingrzejszczak/jenkins-pipeline')
            }
            branch('master')
        }
    }
    steps {
        gradle("clean build")
        dsl {
            external('jobs/*.groovy')
            removeAction('DISABLE')
            removeViewAction('DELETE')
            ignoreExisting(false)
            lookupStrategy('SEED_JOB')
            additionalClasspath([
                'src/main/groovy', 'src/main/resources', 'src/main/bash'
            ].join("\n"))
        }
    }
}

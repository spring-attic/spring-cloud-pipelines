import javaposse.jobdsl.dsl.DslFactory

DslFactory factory = this

String repos = 'https://github.com/marcingrzejszczak/github-analytics,https://github.com/marcingrzejszczak/github-webhook'

factory.job('jenkins-pipeline-seed') {
    scm {
        git {
            remote {
                github('spring-cloud/spring-cloud-pipelines')
            }
            branch('master')
        }
    }
    wrappers {
        parameters {
            stringParam('REPOS', repos,
                    "Provide a comma separated list of repos. If you want the project name to be different then repo name, " +
                            "first provide the name and separate the url with \$ sign")
            stringParam('GIT_CREDENTIAL_ID', 'git', 'ID of the credentials used to push tags to git repo')
            stringParam('JDK_VERSION', 'jdk8', 'ID of Git installation')
            stringParam('CF_TEST_CREDENTIAL_ID', 'cf-test', 'ID of the CF credentials for test environment')
            stringParam('CF_STAGE_CREDENTIAL_ID', 'cf-stage', 'ID of the CF credentials for stage environment')
            stringParam('CF_PROD_CREDENTIAL_ID', 'cf-prod', 'ID of the CF credentials for prod environment')
            stringParam('CF_TEST_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for test env')
            stringParam('CF_STAGE_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for stage env')
            stringParam('CF_PROD_API_URL', 'api.local.pcfdev.io', 'URL to CF Api for prod env')
            stringParam('CF_TEST_ORG', 'pcfdev-org', 'Name of the CF organization for test env')
            stringParam('CF_TEST_SPACE', 'pcfdev-test', 'Name of the CF space for test env')
            stringParam('CF_STAGE_ORG', 'pcfdev-org', 'Name of the CF organization for stage env')
            stringParam('CF_STAGE_SPACE', 'pcfdev-stage', 'Name of the CF space for stage env')
            stringParam('CF_PROD_ORG', 'pcfdev-org', 'Name of the CF organization for prod env')
            stringParam('CF_PROD_SPACE', 'pcfdev-prod', 'Name of the CF space for prod env')
            stringParam('M2_SETTINGS_REPO_ID', 'artifactory-local', "Name of the server ID in Maven's settings.xml")
            stringParam('REPO_WITH_JARS', 'http://artifactory:8081/artifactory/libs-release-local', "Address to hosted JARs")
            stringParam('GIT_EMAIL', 'email@example.com', "Email used to tag the repo")
            stringParam('GIT_NAME', 'Pivo Tal', "Name used to tag the repo")
            booleanParam('AUTO_DEPLOY_TO_STAGE', false, 'Should deployment to stage be automatic')
            booleanParam('AUTO_DEPLOY_TO_PROD', false, 'Should deployment to prod be automatic')
            booleanParam('ROLLBACK_STEP_REQUIRED', true, 'Should rollback step be present')
        }
    }
    steps {
        gradle("clean build")
        dsl {
            external('jenkins/jobs/jenkins_pipeline_sample*.groovy')
            removeAction('DISABLE')
            removeViewAction('DELETE')
            ignoreExisting(false)
            lookupStrategy('SEED_JOB')
            additionalClasspath([
                'jenkins/src/main/groovy', 'jenkins/src/main/resources'
            ].join("\n"))
        }
    }
}

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
    wrappers {
        parameters {
            stringParam('REPOS', 'https://github.com/dsyer/github-analytics,github-webhook$https://github.com/marcingrzejszczak/atom-feed',
                    "Provide a comma separated list of repos. If you want the project name to be different then repo name, " +
                            "first provide the name and separate the url with \$ sign")
            stringParam('GIT_CREDENTIAL_ID', 'git', 'ID of the credentials used to push tags to git repo')
            stringParam('JDK_VERSION', 'jdk8', 'ID of Git installation')
            stringParam('CF_TEST_CREDENTIAL_ID', 'cf-test', 'ID of the CF credentials for test environment')
            stringParam('CF_STAGE_CREDENTIAL_ID', 'cf-stage', 'ID of the CF credentials for stage environment')
            stringParam('CF_PROD_CREDENTIAL_ID', 'cf-prod', 'ID of the CF credentials for prod environment')
            stringParam('CF_API_URL', 'api.local.pcfdev.io', 'URL to CF Api')
            stringParam('CF_TEST_ORG', 'pcfdev-org', 'Name of the CF organization for test env')
            stringParam('CF_TEST_SPACE', 'pcfdev-test', 'Name of the CF space for test env')
            stringParam('CF_STAGE_ORG', 'pcfdev-org', 'Name of the CF organization for stage env')
            stringParam('CF_STAGE_SPACE', 'pcfdev-stage', 'Name of the CF space for stage env')
            stringParam('CF_PROD_ORG', 'pcfdev-org', 'Name of the CF organization for prod env')
            stringParam('CF_PROD_SPACE', 'pcfdev-prod', 'Name of the CF space for prod env')
            stringParam('M2_SETTINGS_REPO_ID', 'artifactory-local', "Name of the server ID in Maven's settings.xml")
            stringParam('REPO_WITH_JARS', 'http://localhost:8081/artifactory/libs-release-local', "Address to hosted JARs")
        }
    }
    steps {
        gradle("clean build")
        dsl {
            external('jobs/jenkins_pipeline_sample*.groovy')
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

import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement

def jobScript = new File('/usr/share/jenkins/jenkins-pipeline.groovy')
def jobManagement = new JenkinsJobManagement(System.out, [:], new File('.'))

new DslScriptLoader(jobManagement).with {
	runScript(jobScript.text)
}

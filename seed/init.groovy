import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement

def cloudSeedJobScript = new File('/usr/share/jenkins/spring-cloud-seed.groovy')
def ioSeedJobScript = new File('/usr/share/jenkins/spring-io-seed.groovy')
def bootSeedJobScript = new File('/usr/share/jenkins/spring-boot-seed.groovy')
def jobManagement = new JenkinsJobManagement(System.out, [:], new File('.'))

new DslScriptLoader(jobManagement).with {
	runScript(cloudSeedJobScript.text)
	runScript(ioSeedJobScript.text)
	runScript(bootSeedJobScript.text)
}


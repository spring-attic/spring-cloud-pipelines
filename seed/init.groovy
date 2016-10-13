import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*

def jobScript = new File('/usr/share/jenkins/jenkins_pipeline.groovy')
def jobManagement = new JenkinsJobManagement(System.out, [:], new File('.'))

println "Creating the settings.xml file"
String m2Home = '/var/jenkins_home/.m2'
boolean m2Created = new File(m2Home).mkdirs()
if (m2Created) {
	boolean settingsCreated = new File("${m2Home}/settings.xml").createNewFile()
	if (settingsCreated) {
		new File("${m2Home}/settings.xml").text =
				new File('/usr/share/jenkins/settings.xml').text
	}
}

println "Creating the seed job"
new DslScriptLoader(jobManagement).with {
	runScript(jobScript.text)
}

println "Creating the credentials"
['cf-test', 'cf-stage', 'cf-prod'].each { String id ->
	SystemCredentialsProvider.getInstance().getCredentials().add(
			new UsernamePasswordCredentialsImpl(CredentialsScope.SYSTEM, id, "CF credential [$id]", "user", "pass"));
	SystemCredentialsProvider.getInstance().save();
}
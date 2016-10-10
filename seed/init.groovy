import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement

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

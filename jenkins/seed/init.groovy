import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.model.*
import jenkins.model.*
import hudson.plugins.groovy.*

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
	} else {
		println "Failed to create settings.xml!"
	}
} else {
	println "Failed to create .m2 folder!"
}

println "Creating the gradle.properties file"
String gradleHome = '/var/jenkins_home/.gradle'
boolean gradleCreated = new File(gradleHome).mkdirs()
if (gradleCreated) {
	boolean settingsCreated = new File("${gradleHome}/gradle.proprties").createNewFile()
	if (settingsCreated) {
		new File("${gradleHome}/gradle.proprties").text =
				new File('/usr/share/jenkins/gradle.properties').text
	}  else {
		println "Failed to create gradle.properties!"
	}
}  else {
	println "Failed to create .gradle folder!"
}

println "Creating the seed job"
new DslScriptLoader(jobManagement).with {
	runScript(jobScript.text.replace('https://github.com/marcingrzejszczak',
			"https://github.com/${System.getenv('FORKED_ORG')}"))
}

println "Creating the credentials"
['cf-test', 'cf-stage', 'cf-prod'].each { String id ->
	boolean credsMissing = SystemCredentialsProvider.getInstance().getCredentials().findAll {
		it.getDescriptor().getId() == id
	}.empty
	if (credsMissing) {
		println "Credential [${id}] is missing - will create it"
		SystemCredentialsProvider.getInstance().getCredentials().add(
				new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, id,
						"CF credential [$id]", "user", "pass"))
		SystemCredentialsProvider.getInstance().save()
	}
}

String gitUser = new File('/usr/share/jenkins/gituser')?.text ?: "changeme"
String gitPass = new File('/usr/share/jenkins/gitpass')?.text ?: "changeme"

boolean gitCredsMissing = SystemCredentialsProvider.getInstance().getCredentials().findAll {
	it.getDescriptor().getId() == 'git'
}.empty

if (gitCredsMissing) {
	println "Credential [git] is missing - will create it"
	SystemCredentialsProvider.getInstance().getCredentials().add(
			new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'git',
					"GIT credential", gitUser, gitPass))
	SystemCredentialsProvider.getInstance().save()
}

println "Adding jdk"
Jenkins.getInstance().getJDKs().add(new JDK("jdk8", "/usr/lib/jvm/java-8-openjdk-amd64"))

println "Marking allow macro token"
Groovy.DescriptorImpl descriptor =
		(Groovy.DescriptorImpl) Jenkins.getInstance().getDescriptorOrDie(Groovy)
descriptor.configure(null, net.sf.json.JSONObject.fromObject('''{"allowMacro":"true"}'''))
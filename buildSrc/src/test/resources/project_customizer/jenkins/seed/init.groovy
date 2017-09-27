import javaposse.jobdsl.dsl.DslScriptLoader
import javaposse.jobdsl.plugin.JenkinsJobManagement
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.impl.*
import hudson.model.*
import jenkins.model.*
import hudson.plugins.groovy.*
import java.nio.file.*

def jobScript = new File('/usr/share/jenkins/jenkins_pipeline.groovy')
def jobManagement = new JenkinsJobManagement(System.out, [:], new File('.'))
String jenkinsHome = '/root'

println "Creating the settings.xml file"
String m2Home = jenkinsHome + '/.m2'
File m2HomeFile = new File(m2Home)
m2HomeFile.mkdirs()
File mavenSettings = new File("${m2Home}/settings.xml")
if (m2HomeFile.exists()) {
	boolean settingsCreated = mavenSettings.createNewFile()
	if (settingsCreated) {
		mavenSettings.text = new File('/usr/share/jenkins/settings.xml').text
	} else if (mavenSettings.exists()) {
		println "Overridden existing maven settings"
		mavenSettings.text = new File('/usr/share/jenkins/settings.xml').text
	} else {
		println "Failed to create settings.xml!"
	}
} else {
	println "Failed to create .m2 folder!"
}

println "Creating the gradle.properties file"
String gradleHome = jenkinsHome + '/.gradle'
File gradleHomeFile = new File(gradleHome)
gradleHomeFile.mkdirs()
File gradleProperties = new File("${gradleHome}/gradle.properties")
if (gradleHomeFile.exists()) {
	boolean settingsCreated = gradleProperties.createNewFile()
	if (settingsCreated) {
		gradleProperties.text =
				new File('/usr/share/jenkins/gradle.properties').text
	} else if (gradleProperties.exists()) {
		println "Overridden existing gradle settings"
		gradleProperties.text =
			new File('/usr/share/jenkins/gradle.properties').text
	} else {
		println "Failed to create gradle.properties!"
	}
}  else {
	println "Failed to create .gradle folder!"
}

println "Creating the seed job"
new DslScriptLoader(jobManagement).with {
	runScript(jobScript.text
			.replace('https://github.com/marcingrzejszczak', "https://github.com/${System.getenv('FORKED_ORG') ?: "marcingrzejszczak"}")
			.replace('http://artifactory', "http://${System.getenv('EXTERNAL_IP') ?: "localhost"}")
			.replace('scpipelines', "${System.getenv('DOCKER_REGISTRY_ORGANIZATION') ?: "scpipelines"}"))
}

// remove::start[CF]
println "Creating the credentials for CF"
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
// remove::end[CF]

println "Adding credentials to deploy to the repo with jars"
String repoWithJarsId = "repo-with-binaries"
boolean repoWithJarCredsMissing = SystemCredentialsProvider.getInstance().getCredentials().findAll {
	it.getDescriptor().getId() == repoWithJarsId
}.empty
if (repoWithJarCredsMissing) {
	println "Credential [${repoWithJarsId}] is missing - will create it"
	SystemCredentialsProvider.getInstance().getCredentials().add(
			new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, repoWithJarsId,
					"Repo with jars credential [${repoWithJarsId}]", "admin", "password"))
	SystemCredentialsProvider.getInstance().save()
}

println "Importing GPG Keys"
def privateKey = new File('/usr/share/jenkins/private.key')
def publicKey = new File('/usr/share/jenkins/public.key')

void importGpgKey(String path) {
	def sout = new StringBuilder(), serr = new StringBuilder()
	String command = "gpg --import " + path
	def proc = command.execute()
	proc.consumeProcessOutput(sout, serr)
	proc.waitForOrKill(1000)
	println "out> $sout err> $serr"
}

if (privateKey.exists()) {
	println "Importing private key from " + privateKey.getPath()
	importGpgKey(privateKey.getPath())
	privateKey.delete()
} else {
	println "Private key file does not exist in " + privateKey.getPath()
}

if (publicKey.exists()) {
	println "Importing public key from " + publicKey.getPath()
	importGpgKey(publicKey.getPath())
	publicKey.delete()
} else {
	println "Public key file does not exist in " + publicKey.getPath()
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

// remove::start[K8S]
def certificateAuthority = new File('/usr/share/jenkins/cert/ca.crt')
def clientCertificate = new File('/usr/share/jenkins/cert/apiserver.crt')
def clientKey = new File('/usr/share/jenkins/cert/apiserver.key')
def kubernetesHome = new File("${jenkinsHome}/.kubernetes/")

if (certificateAuthority.exists() && !kubernetesHome.exists()) {
	println "Copying Kubernetes certificates"
	File targetFile = new File("${jenkinsHome}/.kubernetes/")
	Files.copy(new File('/usr/share/jenkins/cert/').toPath(), targetFile.toPath())
}
if (kubernetesHome.exists()) {
	println "The .kubernetes folder is already created - won't copy the certificates"
}

String dockerRegistryUser = new File('/usr/share/jenkins/dockerRegistryUser')?.text ?: "changeme"
String dockerRegistryPass = new File('/usr/share/jenkins/dockerRegistryPass')?.text ?: "changeme"
String dockerRegistryEmail = new File('/usr/share/jenkins/dockerRegistryEmail')?.text ?: "change@me.com"

println "Updating maven settings with docker registry data"
mavenSettings.text = mavenSettings.text
		.replace("dockeruser", dockerRegistryUser)
		.replace("dockerpass", dockerRegistryPass)
		.replace("docker@email.com", dockerRegistryEmail)

println "Updating gradle properties with docker registry data"
gradleProperties.text = gradleProperties.text
	.replace("dockeruser", dockerRegistryUser)
	.replace("dockerpass", dockerRegistryPass)
	.replace("docker@email.com", dockerRegistryEmail)

println "Adding MySQL credentials"
boolean mySqlCredsMissing = SystemCredentialsProvider.getInstance().getCredentials().findAll {
	it.getDescriptor().getId().startsWith('mysql')
}.empty

String mySqlRootPass = new File('/usr/share/jenkins/mySqlRootPass')?.text ?: "rootpassword"
String mySqlPass = new File('/usr/share/jenkins/mySqlPass')?.text ?: "username"
String mySqlUser = new File('/usr/share/jenkins/mySqlUser')?.text ?: "password"

if (mySqlCredsMissing) {
	println "MySQL credentials are missing - will create it"
	SystemCredentialsProvider.getInstance().getCredentials().add(
			new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'mysql-root',
					"MySQL root credentials", "root", mySqlRootPass))
	SystemCredentialsProvider.getInstance().getCredentials().add(
			new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'mysql',
					"MySQL credentials", mySqlPass, mySqlUser))
	SystemCredentialsProvider.getInstance().save()
}
// remove::end[K8S]

println "Adding jdk"
Jenkins.getInstance().getJDKs().add(new JDK("jdk8", "/usr/lib/jvm/java-8-openjdk-amd64"))

println "Marking allow macro token"
Groovy.DescriptorImpl descriptor =
		(Groovy.DescriptorImpl) Jenkins.getInstance().getDescriptorOrDie(Groovy)
descriptor.configure(null, net.sf.json.JSONObject.fromObject('''{"allowMacro":"true"}'''))

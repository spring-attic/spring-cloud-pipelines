package org.springframework.cloud.pipelines

import spock.lang.Specification

/**
 * @author Marcin Grzejszczak
 */
class OptionsReaderSpec extends Specification {

	def 'should parse input to valid input'() {
		given:
			InputReader reader = Stub(InputReader)
			reader.readLine(_, _) >> "cf" >> "Jenkins"
			OptionsReader optionsReader = new OptionsReader(reader)
		when:
			Options options = optionsReader.read()
		then:
			options.paasType == Options.PaasType.CF
			options.ciTool == Options.CiTool.JENKINS
	}

	def 'should return BOTH if no input received'() {
		given:
			InputReader reader = Stub(InputReader)
			reader.readLine(_, _) >> "\n" >> ""
			OptionsReader optionsReader = new OptionsReader(reader)
		when:
			Options options = optionsReader.read()
		then:
			options.paasType == Options.PaasType.BOTH
			options.ciTool == Options.CiTool.BOTH
	}

	def 'should throw exception when parsing invalid input'() {
		given:
			InputReader reader = Stub(InputReader)
			reader.readLine(_, _) >> "cfaaaa" >> "Jenkinsaaaa"
			OptionsReader optionsReader = new OptionsReader(reader)
		when:
			optionsReader.read()
		then:
			IllegalStateException e = thrown(IllegalStateException)
			e.message.contains("Failed to parse the input. Remember that you can choose")
	}
}

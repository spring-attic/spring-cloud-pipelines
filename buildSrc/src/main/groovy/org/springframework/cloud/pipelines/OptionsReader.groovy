package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.PackageScope

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
@PackageScope
class OptionsReader {

	private final InputReader inputReader

	OptionsReader(InputReader inputReader) {
		this.inputReader = inputReader
	}

	Options read() {
		try {
			inputReader.println("=== PAAS TYPE ===")
			inputReader.println("Which PAAS type do you want to use? Options: ${Options.PaasType.values()}")
			String paasType = textOrDefault(
				inputReader.readLine(),
				Options.PaasType.BOTH.toString()
			)
			inputReader.println("\nYou chose [${Options.PaasType.valueOf(paasType.toUpperCase())}]\n\n")
			inputReader.println("=== CI TOOL ===")
			inputReader.println("Which CI tool do you want to use? Options: ${Options.CiTool.values()}")
			String ciTool = textOrDefault(
				inputReader.readLine(),
				Options.CiTool.BOTH.toString()
			)
			inputReader.println("\nYou chose [${Options.CiTool.valueOf(ciTool.toUpperCase())}]\n\n")
			Options.PaasType paasTypeEnum = Options.PaasType.valueOf(paasType.toUpperCase())
			Options.CiTool ciToolEnum = Options.CiTool.valueOf(ciTool.toUpperCase())
			return Options.builder()
				.ciTool(ciToolEnum)
				.paasType(paasTypeEnum)
				.build()
		} catch (Exception e) {
			throw new IllegalStateException("Failed to parse the input. " +
				"Remember that you can choose these PAAS types ${Options.PaasType.values()} and these CI tools ${Options.CiTool.values()}"
				, e)
		}
	}

	private String textOrDefault(String text, String defaultValue) {
		return text.matches("\\s*") ? defaultValue : text
	}
}

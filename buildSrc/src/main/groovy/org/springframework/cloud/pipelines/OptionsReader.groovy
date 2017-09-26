package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 */
@CompileStatic
class OptionsReader {

	private final InputReader inputReader

	OptionsReader(InputReader inputReader) {
		this.inputReader = inputReader
	}

	Options read() {
		try {
			inputReader.println("=== PAAS TYPE ===")
			String paasType = textOrDefault(
				inputReader.readLine("Which PAAS type do you want to use? Options: ${Options.PaasType.values()}"),
				Options.PaasType.BOTH.toString()
			)
			inputReader.println("=== CI TOOL ===")
			String ciTool = textOrDefault(
				inputReader.readLine("Which CI tool do you want to use? Options: ${Options.CiTool.values()}"),
				Options.CiTool.BOTH.toString()
			)
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

package org.springframework.cloud.pipelines

import groovy.transform.CompileStatic
import groovy.transform.ToString
import groovy.transform.builder.Builder

/**
 * @author Marcin Grzejszczak
 */
@ToString(ignoreNulls = true)
@CompileStatic
@Builder
class Options {

	/**
	 * Used PAAS. Not the one that should be deleted
	 */
	PaasType paasType = PaasType.ALL

	/**
	 * Used CI tool. Not the one that should be deleted
	 */
	CiTool ciTool = CiTool.ALL

	List<String> asKeywordsToDelete() {
		List<String> paases = passes()
		List<String> cis = cis()
		return paases + cis
	}

	private List<String> passes() {
		if (!paasType || paasType == PaasType.ALL) {
			return []
		}
		return (PaasType.values() - paasType - PaasType.ALL).collect { it.toString() }
	}

	private List<String> cis() {
		if (!ciTool || ciTool == CiTool.ALL) {
			return []
		}
		return (CiTool.values() - ciTool - CiTool.ALL).collect { it.toString() }
	}

	enum PaasType {
		CF, K8S, SPINNAKER, ALL
	}

	enum CiTool {
		JENKINS, CONCOURSE, ALL
	}
}

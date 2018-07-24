package org.springframework.cloud.pipelines.util

import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 */
import groovy.xml.XmlUtil
import javaposse.jobdsl.dsl.Item
import org.xmlunit.builder.DiffBuilder
import org.xmlunit.diff.DefaultNodeMatcher
import org.xmlunit.diff.Diff
import org.xmlunit.diff.ElementSelectors

@CompileStatic
trait XmlComparator {

	void assertThatJobIsOk(String name, String value) {
		compareXmls("/default_pipeline/jobs/${name}.xml", value)
	}

	void assertThatViewIsOk(String name, String value) {
		compareXmls("/default_pipeline/views/${name}.xml", value)
	}

	void compareXmls(String file, String nodeToCompare) {
		String referenceXml = XmlUtil.serialize(getFileContent(file)).stripIndent().stripMargin()
		String nodeXml = XmlUtil.serialize(nodeToCompare).stripIndent().stripMargin()
		Diff diff = DiffBuilder.compare(referenceXml).withTest(nodeXml)
			.ignoreWhitespace()
			.ignoreElementContentWhitespace()
			.ignoreComments()
			.withNodeMatcher(new DefaultNodeMatcher(ElementSelectors.byName))
			.checkForSimilar()
			.build()
		if (diff.hasDifferences()) {
			throw new XmlsAreNotSimilar(file, diff.getDifferences())
		}
	}

	private static String getFileContent(String file) {
		new File(XmlComparator.getResource(file).toURI()).getCanonicalFile().text
	}

	static class XmlsAreNotSimilar extends RuntimeException {
		XmlsAreNotSimilar(String file, Iterable diffs) {
			super("For file [$file] the following differences where found [$diffs]")
		}
	}
}

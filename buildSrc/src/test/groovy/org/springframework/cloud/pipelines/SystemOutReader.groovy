package org.springframework.cloud.pipelines

/**
 * @author Marcin Grzejszczak
 */
class SystemOutReader implements InputReader {
	@Override
	void println(String text) {
		println text
	}

	@Override
	String readLine() {
		return null
	}
}

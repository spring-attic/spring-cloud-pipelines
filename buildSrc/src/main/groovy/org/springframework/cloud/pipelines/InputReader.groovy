package org.springframework.cloud.pipelines

/**
 * @author Marcin Grzejszczak
 */
interface InputReader {
	void println(String text)
	String readLine(String text, Object... args)
}

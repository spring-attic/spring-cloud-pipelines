package org.springframework.cloud.pipelines.common

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import groovy.transform.CompileStatic

/**
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class PipelineDescriptor {
	String language_type
	Build build = new Build()
	Pipeline pipeline = new Pipeline()
	Services test = new Services()
	Services stage = new Services()

	@CompileStatic
	static class Build {
		Boolean auto_stage
		Boolean auto_prod
		Boolean api_compatibility_step
		Boolean rollback_step
		Boolean stage_step
	}

	@CompileStatic
	static class Pipeline {
		String main_module
	}

	@CompileStatic
	static class Services {
		List<Service> services = []
	}

	@CompileStatic
	static class Service {
		String type, name, coordinates, pathToManifest, broker, plan
	}

	static PipelineDescriptor from(String yaml) {
		if (!yaml) {
			return new PipelineDescriptor()
		}
		ObjectMapper objectMapper = new ObjectMapper(new YAMLFactory())
		objectMapper.configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false)
		return objectMapper.readValue(yaml, PipelineDescriptor)
	}
}

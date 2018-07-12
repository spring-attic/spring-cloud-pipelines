package org.springframework.cloud.pipelines.common

import com.fasterxml.jackson.databind.ObjectMapper
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
	Services services = new Services()

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
		String noComments = yaml.readLines().findAll {
			!it.trim().stripIndent().stripMargin().startsWith("#")
		}
		ObjectMapper objectMapper = new ObjectMapper()
		return objectMapper.readValue(noComments, PipelineDescriptor)
	}
}

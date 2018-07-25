package org.springframework.cloud.pipelines.common

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory
import groovy.transform.CompileStatic

/**
 * The model representing {@code sc-pipelines.yml} descriptor
 *
 * @author Marcin Grzejszczak
 * @since 1.0.0
 */
@CompileStatic
class PipelineDescriptor {
	String language_type
	Build build = new Build()
	Pipeline pipeline = new Pipeline()
	Environment test = new Environment()
	Environment stage = new Environment()
	Environment prod = new Environment()

	boolean hasMonoRepoProjects() {
		return !pipeline.project_names.empty
	}

	@CompileStatic
	static class Build {
		String main_module
	}

	@CompileStatic
	static class Pipeline {
		List<String> project_names = []
		Boolean api_compatibility_step
		Boolean test_step
		Boolean rollback_step
		Boolean stage_step
		Boolean auto_stage
		Boolean auto_prod
	}

	@CompileStatic
	static class Environment {
		List<Service> services = []
		String deployment_strategy = ""
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

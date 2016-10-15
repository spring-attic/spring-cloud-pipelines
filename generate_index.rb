require 'asciidoctor'

Asciidoctor.convert_file 'docs/spring-cloud-pipelines.adoc', to_file: true, safe: :safe
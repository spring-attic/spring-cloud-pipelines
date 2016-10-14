require 'asciidoctor'

Asciidoctor.convert_file 'docs/index.adoc', to_file: true, safe: :safe
# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      # Builds per-namespace element catalogs from a SchemaRepository.
      # Single-purpose: walk schemas, group their top-level elements by
      # target namespace, attach prefix/occurrence/documentation metadata.
      class ElementCatalog
        attr_reader :repository

        def initialize(repository)
          @repository = repository
        end

        # @param namespace_uri [String, nil] Filter to a single namespace
        # @return [Hash{String => Array<Hash>}] Elements grouped by namespace
        def by_namespace(namespace_uri: nil)
          results = {}

          repository.all_schemas.each_value do |schema|
            ns = schema.target_namespace
            next if namespace_uri && ns != namespace_uri

            results[ns] ||= (schema.element || []).map { |elem| info_for(elem, ns) }
          end

          results
        end

        private

        def info_for(elem, namespace_uri)
          {
            name: elem.name,
            qualified_name: "#{repository.namespace_to_prefix(namespace_uri)}:#{elem.name}",
            type: elem.type || "(inline complex type)",
            min_occurs: elem.min_occurs || "1",
            max_occurs: elem.max_occurs || "1",
            documentation: DocumentationExtractor.call(elem),
          }
        end
      end
    end
  end
end

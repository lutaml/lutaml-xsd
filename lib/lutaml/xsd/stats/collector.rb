# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      # Pure computation: walk a SchemaRepository and produce a flat stats
      # hash. No formatting, no I/O. Deterministic for a given repository
      # state.
      class Collector
        attr_reader :repository

        def initialize(repository)
          @repository = repository
        end

        def call
          type_stats = repository.type_index.statistics

          {
            total_schemas: repository.parsed_schemas.size,
            total_types: type_stats[:total_types],
            types_by_category: type_stats[:by_type],
            total_namespaces: type_stats[:namespaces],
            namespace_prefixes: repository.namespace_registry.all_prefixes.size,
            resolved: repository.resolved,
            validated: repository.validated,
          }
        end

        def namespace_summary
          repository.all_namespaces.map do |ns|
            {
              uri: ns,
              prefix: repository.namespace_to_prefix(ns),
              types: repository.types_in_namespace(ns).size,
            }
          end
        end
      end
    end
  end
end

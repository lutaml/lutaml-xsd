# frozen_string_literal: true

module Lutaml
  module Xsd
    # Provides statistics and export functionality for the repository.
    # Extracted from SchemaRepository to separate export concerns.
    class SchemaExporter
      def initialize(repository)
        @repository = repository
      end

      # Get repository statistics
      # @return [Hash] Statistics about the repository
      def statistics
        type_stats = @repository.type_index.statistics

        {
          total_schemas: @repository.parsed_schemas.size,
          total_types: type_stats[:total_types],
          types_by_category: type_stats[:by_type],
          total_namespaces: type_stats[:namespaces],
          namespace_prefixes: @repository.namespace_registry.all_prefixes.size,
          resolved: @repository.resolved,
          validated: @repository.validated,
        }
      end

      # Export statistics in different formats
      # @param format [Symbol] Output format (:yaml, :json, or :text)
      # @return [String] Formatted statistics
      def export_statistics(format: :yaml)
        stats = statistics

        case format
        when :yaml
          require "yaml"
          stats.to_yaml
        when :json
          require "json"
          JSON.pretty_generate(stats)
        when :text
          format_as_text(stats)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end

      # Get a namespace summary
      # @return [Array<Hash>] Summary of each namespace
      def namespace_summary
        @repository.all_namespaces.map do |ns|
          {
            uri: ns,
            prefix: @repository.namespace_to_prefix(ns),
            types: @repository.types_in_namespace(ns).size,
          }
        end
      end

      # Get all elements organized by namespace
      # @param namespace_uri [String, nil] Filter by specific namespace URI
      # @return [Hash{String => Array<Hash>}] Elements grouped by namespace
      def elements_by_namespace(namespace_uri: nil)
        results = {}

        @repository.all_schemas.each_value do |schema|
          ns = schema.target_namespace
          next if namespace_uri && ns != namespace_uri

          results[ns] ||= []

          (schema.element || []).each do |elem|
            results[ns] << {
              name: elem.name,
              qualified_name: "#{@repository.namespace_to_prefix(ns)}:#{elem.name}",
              type: elem.type || "(inline complex type)",
              min_occurs: elem.min_occurs || "1",
              max_occurs: elem.max_occurs || "1",
              documentation: extract_element_documentation(elem),
            }
          end
        end

        results
      end

      private

      def format_as_text(stats)
        lines = []
        lines << "Schema Repository Statistics"
        lines << ("=" * 40)
        lines << "Total Schemas: #{stats[:total_schemas]}"
        lines << "Total Types: #{stats[:total_types]}"
        lines << "Total Namespaces: #{stats[:total_namespaces]}"
        lines << "Namespace Prefixes: #{stats[:namespace_prefixes]}"
        lines << ""
        lines << "Types by Category:"
        stats[:types_by_category].each do |type, count|
          lines << "  #{type}: #{count}"
        end
        lines << ""
        lines << "Resolved: #{stats[:resolved]}"
        lines << "Validated: #{stats[:validated]}"
        lines.join("\n")
      end

      def extract_element_documentation(elem)
        return "" unless elem.annotation&.documentation

        docs = elem.annotation.documentation
        docs = [docs] unless docs.is_a?(Array)

        docs.filter_map do |doc|
          content = doc.content || doc.to_s
          content&.strip
        end.first || ""
      end
    end
  end
end

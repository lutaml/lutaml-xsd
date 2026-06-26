# frozen_string_literal: true

module Lutaml
  module Xsd
    # Public entry point for repository statistics and namespace/element
    # summaries. Computation, formatting, and documentation extraction are
    # delegated to focused collaborators under `Lutaml::Xsd::Stats`.
    class SchemaExporter
      def initialize(repository)
        @repository = repository
      end

      # @return [Hash] Statistics about the repository
      def statistics
        collector.call
      end

      # @param format [Symbol] Output format (:yaml, :json, :text)
      # @return [String] Formatted statistics
      def export_statistics(format: :yaml)
        Stats::Formatters.render(statistics, format: format)
      end

      # @return [Array<Hash>] Per-namespace summary
      def namespace_summary
        collector.namespace_summary
      end

      # @param namespace_uri [String, nil] Filter by specific namespace URI
      # @return [Hash{String => Array<Hash>}] Elements grouped by namespace
      def elements_by_namespace(namespace_uri: nil)
        element_catalog.by_namespace(namespace_uri: namespace_uri)
      end

      private

      def collector
        @collector ||= Stats::Collector.new(@repository)
      end

      def element_catalog
        @element_catalog ||= Stats::ElementCatalog.new(@repository)
      end
    end
  end
end

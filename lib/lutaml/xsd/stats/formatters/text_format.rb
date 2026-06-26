# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      module Formatters
        # Human-readable plain text rendering of repository stats.
        class TextFormat < Base
          # @param stats [Hash] Output of Stats::Collector#call
          # @return [String]
          def self.render(stats)
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
        end

        register(:text, TextFormat)
      end
    end
  end
end

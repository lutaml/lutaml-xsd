# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      # Registry-driven formatting for stats hashes produced by Collector.
      #
      # New formats are added by creating a class under Formatters (e.g.,
      # HtmlFormat) that implements `self.render(stats)`, adding an autoload
      # entry below, and self-registering at the bottom of the new file.
      # No existing class needs to be modified.
      module Formatters
        autoload :Base, "lutaml/xsd/stats/formatters/base"
        autoload :TextFormat, "lutaml/xsd/stats/formatters/text_format"
        autoload :JsonFormat, "lutaml/xsd/stats/formatters/json_format"
        autoload :YamlFormat, "lutaml/xsd/stats/formatters/yaml_format"

        @registered = {}

        # Register a formatter class for a format symbol.
        # @param format [Symbol] e.g., :text, :json, :yaml
        # @param klass [Class] Subclass of Formatters::Base
        def self.register(format, klass)
          @registered[format.to_sym] = klass
        end

        # Look up the formatter for a format. Triggers autoload so the
        # formatter file can self-register on first reference.
        # @param format [Symbol] e.g., :text, :json, :yaml
        # @return [Class] Subclass of Formatters::Base
        # @raise [ArgumentError] if no formatter is registered for format
        def self.lookup(format)
          key = format.to_sym
          return @registered[key] if @registered.key?(key)

          const_name = :"#{camelize(format)}Format"
          const_get(const_name) if autoload?(const_name)

          @registered.fetch(key) do
            raise ArgumentError, "Unknown format: #{format}"
          end
        end

        # Render stats in the requested format.
        # @param stats [Hash] Output of Stats::Collector#call
        # @param format [Symbol] e.g., :text, :json, :yaml
        # @return [String]
        def self.render(stats, format:)
          lookup(format).render(stats)
        end

        # @!visibility private
        def self.camelize(format)
          format.to_s.split("_").map(&:capitalize).join
        end
        private_class_method :camelize
      end
    end
  end
end

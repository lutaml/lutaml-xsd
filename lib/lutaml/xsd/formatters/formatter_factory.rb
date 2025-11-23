# frozen_string_literal: true

require_relative "text_formatter"
require_relative "json_formatter"
require_relative "yaml_formatter"

module Lutaml
  module Xsd
    module Formatters
      # Factory for creating formatter instances
      # Provides a centralized way to create formatters based on format strings
      class FormatterFactory
        # Registry of available formatters
        FORMATTERS = {
          "text" => TextFormatter,
          "json" => JsonFormatter,
          "yaml" => YamlFormatter
        }.freeze

        # Create a formatter instance for the specified format
        #
        # @param format [String] The format name (text, json, or yaml)
        # @return [Base] A formatter instance
        # @raise [ArgumentError] If the format is unknown
        def self.create(format)
          formatter_class = FORMATTERS[format]
          raise ArgumentError, "Unknown format: #{format}" unless formatter_class

          formatter_class.new
        end

        # Get list of supported format names
        #
        # @return [Array<String>] Array of supported format names
        def self.supported_formats
          FORMATTERS.keys
        end

        # Check if a format is supported
        #
        # @param format [String] The format name to check
        # @return [Boolean] True if the format is supported
        def self.supported?(format)
          FORMATTERS.key?(format)
        end
      end
    end
  end
end
# frozen_string_literal: true

module Lutaml
  module Xsd
    # Base error class for lutaml-xsd errors
    class Error < StandardError; end

    # Schema not found with helpful context
    class SchemaNotFoundError < Error
      attr_reader :location, :searched_paths, :suggestions

      def initialize(location:, searched_paths: [], suggestions: [])
        @location = location
        @searched_paths = searched_paths
        @suggestions = suggestions

        message = build_message
        super(message)
      end

      private

      def build_message
        msg = "Schema not found: #{@location}\n\n"

        if @searched_paths.any?
          msg += "Searched in:\n"
          @searched_paths.each { |path| msg += "  - #{path}\n" }
          msg += "\n"
        end

        if @suggestions.any?
          msg += "Did you mean one of these?\n"
          @suggestions.each { |s| msg += "  - #{s}\n" }
          msg += "\n"
        end

        msg += "💡 See: https://www.lutaml.org/lutaml-xsd/troubleshooting/schema-not-found"
        msg
      end
    end

    # Type not found with resolution path
    class TypeNotFoundError < Error
      attr_reader :qualified_name, :resolution_path, :available_namespaces

      def initialize(qualified_name:, resolution_path: [], available_namespaces: [])
        @qualified_name = qualified_name
        @resolution_path = resolution_path
        @available_namespaces = available_namespaces

        message = build_message
        super(message)
      end

      private

      def build_message
        msg = "Type not found: #{@qualified_name}\n\n"

        if @resolution_path.any?
          msg += "Resolution path:\n"
          @resolution_path.each_with_index { |step, i| msg += "  #{i + 1}. #{step}\n" }
          msg += "\n"
        end

        if @available_namespaces.any?
          msg += "Available namespaces:\n"
          @available_namespaces.first(5).each { |ns| msg += "  - #{ns}\n" }
          msg += "  ... and #{@available_namespaces.size - 5} more\n" if @available_namespaces.size > 5
          msg += "\n"
        end

        msg += "💡 See: https://www.lutaml.org/lutaml-xsd/troubleshooting/type-not-found"
        msg
      end
    end

    # Package validation error
    class PackageValidationError < Error; end

    # Configuration error
    class ConfigurationError < Error; end
  end
end

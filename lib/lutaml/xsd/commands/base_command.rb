# frozen_string_literal: true

require "json"
require "yaml"

module Lutaml
  module Xsd
    module Commands
      # Base class for all CLI commands
      # Provides common functionality for error handling and output formatting
      class BaseCommand
        attr_reader :options

        def initialize(options = {})
          @options = options
        end

        # Run the command
        # Must be implemented by subclasses
        def run
          raise NotImplementedError, "Subclass must implement #run method"
        end

        private

        # Check if verbose mode is enabled
        # @return [Boolean]
        def verbose?
          options[:verbose] || options["verbose"]
        end

        # Output message to stdout
        # @param message [String] Message to output
        def output(message)
          puts message
        end

        # Output message only in verbose mode
        # @param message [String] Message to output
        def verbose_output(message)
          output(message) if verbose?
        end

        # Output error message to stderr
        # @param message [String] Error message
        def error(message)
          warn "ERROR: #{message}"
        end

        # Format output based on specified format
        # @param data [Hash, Array] Data to format
        # @param format [String] Output format (text, json, yaml)
        # @return [String] Formatted output
        def format_output(data, format = nil)
          format ||= options[:format] || options["format"] || "text"

          case format.to_s
          when "json"
            JSON.pretty_generate(data)
          when "yaml"
            data.to_yaml
          else
            # Text format - must be handled by subclass
            data.to_s
          end
        end

        # Load repository from package file
        # @param package_path [String] Path to .lxr package
        # @return [SchemaRepository]
        def load_repository(package_path)
          unless File.exist?(package_path)
            error "Package file not found: #{package_path}"
            exit 1
          end

          verbose_output "Loading repository from: #{package_path}"
          repository = SchemaRepository.from_package(package_path)
          verbose_output "✓ Repository loaded successfully"
          repository
        rescue StandardError => e
          error "Failed to load repository: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          exit 1
        end

        # Parse and resolve repository if needed
        # @param repository [SchemaRepository]
        # @return [SchemaRepository]
        def ensure_resolved(repository)
          if repository.needs_parsing?
            verbose_output "Parsing schemas from XSD files..."
            repository.parse
            verbose_output "✓ Schemas parsed"
          else
            verbose_output "✓ Schemas loaded from package (instant load)"
          end

          verbose_output "Resolving cross-references and building type index..."
          repository.resolve
          verbose_output "✓ Repository resolved"

          repository
        rescue StandardError => e
          error "Failed to resolve repository: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          exit 1
        end
      end
    end
  end
end

# frozen_string_literal: true

require_relative "base_command"
require_relative "../validation/validator"

module Lutaml
  module Xsd
    module Commands
      # CLI command for XML instance validation
      #
      # Validates XML files against XSD schemas with support for:
      # - Single file validation
      # - Multiple file validation (glob patterns)
      # - Various output formats (text, json, yaml)
      # - Exit codes based on validation result
      class ValidateCommand < BaseCommand
        attr_reader :xml_files, :schema_source

        # Initialize validate command
        #
        # @param xml_files [Array<String>] XML file paths or glob patterns
        # @param schema_source [String] Schema package path or repository
        # @param options [Hash] Command options
        def initialize(xml_files, schema_source, options = {})
          super(options)
          @xml_files = Array(xml_files)
          @schema_source = schema_source
        end

        # Run validation command
        #
        # @return [void]
        def run
          validate_inputs
          files = expand_file_patterns

          if files.empty?
            error "No XML files found matching the specified patterns"
            exit 1
          end

          validator = create_validator
          results = validate_files(files, validator)

          output_results(results)
          exit_with_status(results)
        rescue StandardError => e
          error "Validation failed: #{e.message}"
          verbose_output e.backtrace.join("\n") if verbose?
          exit 1
        end

        private

        # Validate command inputs
        #
        # @return [void]
        def validate_inputs
          if xml_files.empty?
            error "No XML files specified"
            error "Usage: lutaml-xsd validate FILES SCHEMA [options]"
            exit 1
          end

          unless File.exist?(schema_source)
            error "Schema source not found: #{schema_source}"
            exit 1
          end
        end

        # Expand glob patterns to file list
        #
        # @return [Array<String>] List of XML files
        def expand_file_patterns
          files = []
          xml_files.each do |pattern|
            if pattern.include?("*") || pattern.include?("?")
              files.concat(Dir.glob(pattern))
            elsif File.exist?(pattern)
              files << pattern
            else
              error "File not found: #{pattern}"
            end
          end
          files.uniq.sort
        end

        # Create validator instance
        #
        # @return [Lutaml::Xsd::Validation::Validator] Validator instance
        def create_validator
          verbose_output "Loading schema source: #{schema_source}"

          config = options[:config] ? load_config(options[:config]) : nil
          validator = Lutaml::Xsd::Validation::Validator.new(schema_source, config: config)

          verbose_output "✓ Validator initialized"
          validator
        end

        # Load validation configuration
        #
        # @param config_path [String] Path to config file
        # @return [Hash] Configuration hash
        def load_config(config_path)
          unless File.exist?(config_path)
            error "Configuration file not found: #{config_path}"
            exit 1
          end

          YAML.load_file(config_path)
        end

        # Validate all files
        #
        # @param files [Array<String>] List of XML files
        # @param validator [Validator] Validator instance
        # @return [Array<Hash>] Validation results
        def validate_files(files, validator)
          results = []

          files.each do |file|
            verbose_output "Validating: #{file}"
            result = validate_single_file(file, validator)
            results << { file: file, result: result }
          end

          results
        end

        # Validate single file
        #
        # @param file [String] XML file path
        # @param validator [Validator] Validator instance
        # @return [Hash] Validation result
        def validate_single_file(file, validator)
          xml_content = File.read(file)
          validator.validate(xml_content)
        rescue StandardError => e
          {
            valid: false,
            errors: [{
              message: "Failed to read or parse file: #{e.message}",
              location: file
            }]
          }
        end

        # Output validation results
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def output_results(results)
          format = options[:format] || "text"

          case format
          when "json"
            output_json(results)
          when "yaml"
            output_yaml(results)
          else
            output_text(results)
          end
        end

        # Output results as JSON
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def output_json(results)
          output JSON.pretty_generate(format_results_for_json(results))
        end

        # Output results as YAML
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def output_yaml(results)
          output format_results_for_json(results).to_yaml
        end

        # Output results as text
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def output_text(results)
          output ""
          output "Validation Results"
          output "=" * 80
          output ""

          results.each do |item|
            output_file_result(item[:file], item[:result])
          end

          output ""
          output_summary(results)
        end

        # Output single file result
        #
        # @param file [String] File path
        # @param result [Hash] Validation result
        # @return [void]
        def output_file_result(file, result)
          if result.respond_to?(:valid?) ? result.valid? : result[:valid]
            output "✓ #{file}"
          else
            output "✗ #{file}"
            output_errors(result)
          end
          output ""
        end

        # Output validation errors
        #
        # @param result [Hash] Validation result
        # @return [void]
        def output_errors(result)
          errors = result.respond_to?(:errors) ? result.errors : result[:errors]
          return unless errors

          errors.take(options[:max_errors] || 10).each do |error|
            if error.respond_to?(:to_detailed_message)
              output "  #{error.to_detailed_message.gsub("\n", "\n  ")}"
            else
              location = error[:location] ? " at #{error[:location]}" : ""
              output "  • #{error[:message]}#{location}"
            end
          end

          if errors.size > (options[:max_errors] || 10)
            output "  ... and #{errors.size - (options[:max_errors] || 10)} more errors"
          end
        end

        # Output summary
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def output_summary(results)
          total = results.size
          valid = results.count { |r| r[:result].respond_to?(:valid?) ? r[:result].valid? : r[:result][:valid] }
          invalid = total - valid

          output "Summary"
          output "-" * 80
          output "Total files: #{total}"
          output "Valid: #{valid}"
          output "Invalid: #{invalid}"
        end

        # Format results for JSON/YAML output
        #
        # @param results [Array<Hash>] Validation results
        # @return [Hash] Formatted results
        def format_results_for_json(results)
          {
            summary: {
              total: results.size,
              valid: results.count { |r| r[:result].respond_to?(:valid?) ? r[:result].valid? : r[:result][:valid] },
              invalid: results.count { |r| !(r[:result].respond_to?(:valid?) ? r[:result].valid? : r[:result][:valid]) }
            },
            files: results.map do |item|
              {
                file: item[:file],
                valid: item[:result].respond_to?(:valid?) ? item[:result].valid? : item[:result][:valid],
                errors: format_errors_for_json(item[:result])
              }
            end
          }
        end

        # Format errors for JSON output
        #
        # @param result [Hash] Validation result
        # @return [Array<Hash>] Formatted errors
        def format_errors_for_json(result)
          errors = result.respond_to?(:errors) ? result.errors : result[:errors]
          return [] unless errors

          errors.map do |error|
            if error.respond_to?(:to_h)
              error.to_h
            else
              error
            end
          end
        end

        # Exit with appropriate status code
        #
        # @param results [Array<Hash>] Validation results
        # @return [void]
        def exit_with_status(results)
          invalid_count = results.count { |r| !(r[:result].respond_to?(:valid?) ? r[:result].valid? : r[:result][:valid]) }
          exit invalid_count > 0 ? 1 : 0
        end
      end
    end
  end
end
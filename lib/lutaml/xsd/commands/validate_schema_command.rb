# frozen_string_literal: true

require "thor"
require_relative "../schema_validator"
require_relative "../file_validation_result"
require_relative "../validation_result"
require_relative "../formatters/formatter_factory"

module Lutaml
  module Xsd
    module Commands
      # Command for validating XSD schema files
      class ValidateSchemaCommand < Thor
        desc "validate SCHEMA_FILE [SCHEMA_FILE...]",
             "Validate XSD schema files"
        long_desc <<~DESC
          Validates one or more XSD schema files for correctness.

          Checks:
            - XML syntax correctness
            - Proper XML Schema namespace usage
            - XSD version compliance (1.0 or 1.1)

          Output formats:
            - text: Human-readable text output (default)
            - json: JSON format for CI/CD integration
            - yaml: YAML format for CI/CD integration

          Examples:
            lutaml-xsd validate-schema schema.xsd
            lutaml-xsd validate-schema schema1.xsd schema2.xsd
            lutaml-xsd validate-schema *.xsd
            lutaml-xsd validate-schema schema.xsd --version 1.1
            lutaml-xsd validate-schema schema.xsd --format json
            lutaml-xsd validate-schema schema.xsd --format yaml
        DESC
        option :version,
               type: :string,
               default: "1.0",
               desc: "XSD version to validate against (1.0 or 1.1)"
        option :verbose,
               type: :boolean,
               default: false,
               desc: "Enable verbose output"
        option :format,
               type: :string,
               default: "text",
               desc: "Output format: text, json, or yaml"
        def validate(*schema_files)
          if schema_files.empty?
            puts "ERROR: No schema files specified"
            puts "Usage: lutaml-xsd validate-schema SCHEMA_FILE [SCHEMA_FILE...]"
            exit 1
          end

          format = options[:format]
          unless Formatters::FormatterFactory.supported?(format)
            puts "ERROR: Invalid format '#{format}'. Must be 'text', 'json', or 'yaml'"
            exit 1
          end

          version = options[:version]
          verbose = options[:verbose]

          validator = SchemaValidator.new(version: version)
          results = validate_files(schema_files, validator, verbose)

          output_results(results, format)

          exit 1 unless results.failed_files.empty?
          exit 0
        end

        private

        # Validate all schema files and collect results
        def validate_files(schema_files, validator, verbose)
          file_results = schema_files.map do |file|
            hash = validate_single_file(file, validator, verbose)
            FileValidationResult.new(
              file: hash[:file],
              valid: hash[:valid],
              error: hash[:error],
              detected_version: hash[:detected_version]
            )
          end

          ValidationResult.new(file_results)
        end

        # Validate a single schema file
        def validate_single_file(file, validator, verbose)
          result = {
            file: file,
            valid: false,
            error: nil,
            detected_version: nil
          }

          unless File.exist?(file)
            result[:error] = "File not found"
            return result
          end

          begin
            content = File.read(file)
            validator.validate(content)
            result[:valid] = true
            result[:detected_version] = SchemaValidator.detect_version(content) if verbose
          rescue SchemaValidationError => e
            result[:error] = e.message
          rescue StandardError => e
            result[:error] = "Unexpected error: #{e.message}"
          end

          result
        end

        # Output results in the specified format
        def output_results(results, format)
          formatter = Formatters::FormatterFactory.create(format)
          # Convert ValidationResult to Hash for backward compatibility
          result_hash = results.respond_to?(:to_h) ? results.to_h : results
          puts formatter.format(result_hash)
        end
      end
    end
  end
end
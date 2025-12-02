# frozen_string_literal: true

require_relative "validation_result"
require_relative "validation_error"
require_relative "xml_navigator"
require_relative "result_collector"
require_relative "rule_engine"

module Lutaml
  module Xsd
    module Validation
      # ValidationJob executes the validation workflow
      #
      # This class implements the Command pattern to execute XML validation
      # against XSD schemas. It coordinates the validation process through
      # multiple phases: XML parsing, structure validation, type validation,
      # and constraint validation.
      #
      # @example Execute a validation job
      #   job = ValidationJob.new(
      #     xml_content: "<root>...</root>",
      #     repository: schema_repository,
      #     rule_registry: rule_registry,
      #     config: configuration
      #   )
      #   result = job.execute
      class ValidationJob
        # Initialize a new ValidationJob
        #
        # @param xml_content [String] The XML content to validate
        # @param repository [SchemaRepository] The schema repository
        # @param rule_registry [RuleRegistry] Registry of validation rules
        # @param config [ValidationConfiguration] Validation configuration
        #
        # @raise [ArgumentError] if required parameters are missing
        def initialize(xml_content:, repository:, rule_registry:, config:)
          @xml_content = xml_content
          @repository = repository
          @rule_registry = rule_registry
          @config = config
          @result_collector = ResultCollector.new(config)
          @navigator = nil
          @document = nil
          @rule_engine = nil
        end

        # Execute the validation workflow
        #
        # Performs validation in the following order:
        # 1. Parse XML document
        # 2. Validate structure (elements, namespaces)
        # 3. Validate types (simple and complex types)
        # 4. Validate constraints (occurrences, identity constraints)
        #
        # @return [ValidationResult] The complete validation result
        def execute
          return early_result if should_stop_early?

          parse_xml
          return result_from_collector if should_stop_after_parse?

          validate_structure if @config.feature_enabled?(:validate_types)
          return result_from_collector if should_stop_after_structure?

          validate_types if @config.feature_enabled?(:validate_types)
          return result_from_collector if should_stop_after_types?

          validate_constraints if @config.feature_enabled?(:validate_occurrences)
          return result_from_collector if should_stop_after_constraints?

          result_from_collector
        end

        private

        # Parse the XML content into a document object
        #
        # @return [void]
        def parse_xml
          @navigator = XmlNavigator.new(@xml_content)
          @document = @navigator.document
          @rule_engine = RuleEngine.new(@rule_registry, @result_collector)
        rescue Moxml::ParseError => e
          @result_collector.add_error(
            ValidationError.new(
              code: "xml_parse_error",
              message: "Failed to parse XML: #{e.message}",
              severity: :error,
              location: nil,
            ),
          )
        rescue StandardError => e
          @result_collector.add_error(
            ValidationError.new(
              code: "xml_parse_error",
              message: "Unexpected error parsing XML: #{e.message}",
              severity: :error,
              location: nil,
            ),
          )
        end

        # Validate document structure
        #
        # @return [void]
        def validate_structure
          return unless @document && @rule_engine

          @rule_engine.execute_category(:structure, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Validate element types
        #
        # @return [void]
        def validate_types
          return unless @document && @rule_engine

          @rule_engine.execute_category(:type, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Validate constraints
        #
        # @return [void]
        def validate_constraints
          return unless @document && @rule_engine

          @rule_engine.execute_category(:constraint, @document, @repository)
          @rule_engine.execute_category(:facet, @document, @repository)
          @rule_engine.execute_category(:identity, @document, @repository)
        rescue ResultCollector::StopValidationError
          # Stop validation if configured to stop on first error
        end

        # Check if validation should stop early
        #
        # @return [Boolean]
        def should_stop_early?
          @xml_content.nil? || @xml_content.empty?
        end

        # Check if validation should stop after parse
        #
        # @return [Boolean]
        def should_stop_after_parse?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after structure validation
        #
        # @return [Boolean]
        def should_stop_after_structure?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after type validation
        #
        # @return [Boolean]
        def should_stop_after_types?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Check if validation should stop after constraint validation
        #
        # @return [Boolean]
        def should_stop_after_constraints?
          @config.stop_on_first_error? && @result_collector.has_errors?
        end

        # Build early result for invalid input
        #
        # @return [ValidationResult]
        def early_result
          @result_collector.add_error(
            ValidationError.new(
              code: "invalid_input",
              message: "XML content cannot be nil or empty",
              severity: :error,
              location: nil,
            ),
          )
          result_from_collector
        end

        # Build result from collector
        #
        # @return [ValidationResult]
        def result_from_collector
          @result_collector.to_result
        end
      end
    end
  end
end

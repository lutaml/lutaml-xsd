# frozen_string_literal: true

require_relative 'rule_registry'
require_relative 'result_collector'

module Lutaml
  module Xsd
    module Validation
      # RuleEngine executes validation rules by category
      #
      # This class coordinates the execution of validation rules in a
      # specific order, managing the validation workflow and collecting
      # results. It implements the Strategy pattern, delegating actual
      # validation to individual rules.
      #
      # @example Execute validation rules
      #   engine = RuleEngine.new(registry, collector)
      #   engine.execute_category(:structure, document, repository)
      #
      # @example Execute all rules
      #   engine.execute_all(document, repository)
      class RuleEngine
        # @return [RuleRegistry] The rule registry
        attr_reader :registry

        # @return [ResultCollector] The result collector
        attr_reader :collector

        # Initialize a new RuleEngine
        #
        # @param registry [RuleRegistry] The rule registry
        # @param collector [ResultCollector] The result collector
        def initialize(registry, collector)
          @registry = registry
          @collector = collector
        end

        # Execute all rules in a specific category
        #
        # @param category [Symbol] The rule category to execute
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        #
        # @raise [StopValidationError] if stop-on-first-error is enabled
        def execute_category(category, document, repository)
          rules = @registry.rules_for_category(category)

          rules.each do |rule|
            execute_rule(rule, document, repository)
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
          raise
        end

        # Execute all registered rules
        #
        # Executes rules in category order: structure, type, constraint,
        # facet, identity.
        #
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_all(document, repository)
          execute_category(:structure, document, repository)
          execute_category(:type, document, repository)
          execute_category(:constraint, document, repository)
          execute_category(:facet, document, repository)
          execute_category(:identity, document, repository)
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Execute a single rule
        #
        # @param rule [ValidationRule] The rule to execute
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_rule(rule, document, repository)
          return unless rule.enabled?

          rule.validate(document, repository, @collector)
        rescue StandardError => e
          handle_rule_error(rule, e)
        end

        # Execute rules with a custom order
        #
        # @param categories [Array<Symbol>] Categories in desired order
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_with_order(categories, document, repository)
          categories.each do |category|
            execute_category(category, document, repository)
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Execute only enabled rules
        #
        # @param document [XmlDocument] The XML document
        # @param repository [SchemaRepository] The schema repository
        # @return [void]
        def execute_enabled(document, repository)
          enabled_rules = @registry.all_rules(enabled_only: true)

          # Group by category and execute in order
          categories = ValidationRule::CATEGORIES

          categories.each do |category|
            category_rules = enabled_rules.select { |r| r.category == category }
            category_rules.each do |rule|
              execute_rule(rule, document, repository)
            end
          end
        rescue ResultCollector::StopValidationError
          # Stop validation early if configured
        end

        # Get execution statistics
        #
        # @return [Hash] Statistics about rule execution
        def statistics
          {
            total_rules: @registry.all_rules(enabled_only: false).size,
            enabled_rules: @registry.all_rules(enabled_only: true).size,
            categories: @registry.categories.size,
            errors_collected: @collector.errors.size,
            warnings_collected: @collector.warnings.size,
            infos_collected: @collector.infos.size
          }
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            registry: @registry.to_h,
            statistics: statistics
          }
        end

        # String representation
        #
        # @return [String]
        def to_s
          stats = statistics
          "RuleEngine(#{stats[:enabled_rules]}/#{stats[:total_rules]} rules)"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "registry=#{@registry.inspect} " \
            "collector=#{@collector.class.name}>"
        end

        private

        # Handle errors that occur during rule execution
        #
        # @param rule [ValidationRule] The rule that failed
        # @param error [StandardError] The error that occurred
        # @return [void]
        def handle_rule_error(rule, error)
          @collector.add_error(
            ValidationError.new(
              code: 'rule_execution_error',
              message: "Error executing #{rule.class.name}: #{error.message}",
              severity: :error,
              context: {
                rule: rule.class.name,
                category: rule.category,
                error_class: error.class.name,
                backtrace: error.backtrace&.first(5)
              }
            )
          )
        end
      end
    end
  end
end

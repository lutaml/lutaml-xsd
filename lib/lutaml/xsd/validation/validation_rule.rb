# frozen_string_literal: true

module Lutaml
  module Xsd
    module Validation
      # ValidationRule is the base class for all validation rules
      #
      # This abstract class defines the interface that all validation rules
      # must implement. It follows the Template Method pattern, allowing
      # subclasses to define specific validation logic while maintaining
      # a consistent structure.
      #
      # @example Create a custom validation rule
      #   class MyRule < ValidationRule
      #     def category
      #       :structure
      #     end
      #
      #     def validate(document, repository, collector)
      #       # Validation logic here
      #     end
      #   end
      #
      # @example Use a validation rule
      #   rule = MyRule.new(strict: true)
      #   rule.validate(document, repository, collector)
      class ValidationRule
        # Valid rule categories
        CATEGORIES = %i[structure type constraint facet identity].freeze

        # @return [Hash] Rule options
        attr_reader :options

        # Initialize a new ValidationRule
        #
        # @param options [Hash] Rule-specific options
        def initialize(options = {})
          @options = options
          @enabled = options.fetch(:enabled, true)
        end

        # Execute the validation rule
        #
        # This is the main entry point for validation. Rules are
        # element-scoped: the engine calls this once per instance element
        # with the schema argument selected by {#schema_argument}.
        #
        # @abstract
        # @param xml_element [XmlElement] The instance element to validate
        # @param schema_argument [Object, nil] What this rule validates
        #   against (schema element by default; see {#schema_argument})
        # @param collector [ResultCollector] Collector for validation results
        # @param repository [SchemaDefinitionResolver, nil] Named-type
        #   resolution for `type="prefix:Name"` references
        # @return [void]
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def validate(xml_element, schema_argument, collector, repository: nil)
          raise NotImplementedError,
                "#{self.class} must implement #validate"
        end

        # The schema object this rule validates the element against.
        #
        # Defaults to the resolved schema element; rules that need a
        # different shape override this (e.g. the occurrence rule wants
        # the content-model particle).
        #
        # @param schema_def [Object, nil] Resolved schema declaration
        # @param repository [SchemaDefinitionResolver, nil]
        # @return [Object, nil]
        def schema_argument(schema_def, repository: nil) # rubocop:disable Lint/UnusedMethodArgument
          # `repository` is part of the contract; the default selection
          # does not consult it.
          schema_def
        end

        # Whether the rule still runs when no schema declaration resolves.
        #
        # @return [Boolean]
        def runs_without_schema?
          false
        end

        XSI_NAMESPACE = "http://www.w3.org/2001/XMLSchema-instance"

        # Find an xsi:-namespaced attribute on the instance element.
        #
        # @param xml_element [XmlElement]
        # @param name [String] local name (e.g. "nil", "type")
        # @return [XmlAttribute, nil]
        def xsi_attribute(xml_element, name)
          xml_element.attributes.find do |attr|
            attr.name == name && attr.namespace_uri == XSI_NAMESPACE
          end
        end

        # Get the category of this validation rule
        #
        # Categories are used to group rules and execute them in phases:
        # - :structure - Element existence, ordering, namespaces
        # - :type - Type compliance (simple and complex types)
        # - :constraint - Occurrences, patterns, ranges
        # - :facet - Facet validation (length, pattern, etc.)
        # - :identity - Key, keyref, unique constraints
        #
        # @abstract
        # @return [Symbol] The rule category
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def category
          raise NotImplementedError,
                "#{self.class} must implement #category"
        end

        # Get a human-readable description of the rule
        #
        # @abstract
        # @return [String] Rule description
        #
        # @raise [NotImplementedError] if not implemented by subclass
        def description
          raise NotImplementedError,
                "#{self.class} must implement #description"
        end

        # Check if this rule is enabled
        #
        # @return [Boolean]
        def enabled?
          @enabled
        end

        # Disable this rule
        #
        # @return [void]
        def disable!
          @enabled = false
        end

        # Enable this rule
        #
        # @return [void]
        def enable!
          @enabled = true
        end

        # Get rule priority for execution order
        #
        # Rules with lower priority numbers execute first.
        # Default priority is 100.
        #
        # @return [Integer]
        def priority
          @options.fetch(:priority, 100)
        end

        # Check if rule should run for given configuration
        #
        # Category filtering is not implemented in the configuration yet;
        # only the enable flag applies.
        #
        # @param config [ValidationConfiguration] The configuration
        # @return [Boolean]
        def applicable?(_config)
          return false unless enabled?

          true
        end

        # Get option value
        #
        # @param key [Symbol] Option key
        # @param default [Object] Default value if not found
        # @return [Object] Option value
        def option(key, default = nil)
          @options.fetch(key, default)
        end

        # Convert to hash representation
        #
        # @return [Hash]
        def to_h
          {
            class: self.class.name,
            category: category,
            description: description,
            enabled: enabled?,
            priority: priority,
            options: @options,
          }
        end

        # String representation
        #
        # @return [String]
        def to_s
          "#{self.class.name}(category: #{category}, enabled: #{enabled?})"
        end

        # Detailed string representation
        #
        # @return [String]
        def inspect
          "#<#{self.class.name} " \
            "category=#{category.inspect} " \
            "enabled=#{enabled?} " \
            "priority=#{priority}>"
        end

        protected

        # Helper method to create validation errors
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Error code
        # @param message [String] Error message
        # @param location [String, nil] Error location
        # @param context [Hash, nil] Additional context
        # @param suggestion [String, nil] Suggested fix
        # @return [void]
        def report_error(collector, code:, message:, location: nil,
                         context: nil, suggestion: nil)
          error = ValidationError.new(
            code: code,
            message: message,
            severity: :error,
            location: location,
            context: context,
            suggestion: suggestion,
          )
          collector.add_error(error)
        end

        # Helper method to create validation warnings
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Warning code
        # @param message [String] Warning message
        # @param location [String, nil] Warning location
        # @param context [Hash, nil] Additional context
        # @param suggestion [String, nil] Suggested fix
        # @return [void]
        def report_warning(collector, code:, message:, location: nil,
                           context: nil, suggestion: nil)
          warning = ValidationError.new(
            code: code,
            message: message,
            severity: :warning,
            location: location,
            context: context,
            suggestion: suggestion,
          )
          collector.add_warning(warning)
        end

        # Helper method to create validation info messages
        #
        # @param collector [ResultCollector] The result collector
        # @param code [String] Info code
        # @param message [String] Info message
        # @param location [String, nil] Info location
        # @param context [Hash, nil] Additional context
        # @return [void]
        def report_info(collector, code:, message:, location: nil,
                        context: nil)
          info = ValidationError.new(
            code: code,
            message: message,
            severity: :info,
            location: location,
            context: context,
          )
          collector.add_info(info)
        end
      end
    end
  end
end

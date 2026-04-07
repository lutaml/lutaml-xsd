# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # TypeValidationRule validates element types
        #
        # This rule checks:
        # - Resolves element type from schema
        # - Validates simple type content
        # - Validates complex type content
        # - Delegates to base type validators and facet validators
        #
        # Based on Jing validator type validation algorithm.
        #
        # @example Using the rule
        #   rule = TypeValidationRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Type Validation
        class TypeValidationRule < ValidationRule
          # Rule category
          #
          # @return [Symbol] :type
          def category
            :type
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element content against XSD type definitions"
          end

          # Validate element type
          #
          # Validates the element's content against its type definition,
          # handling both simple and complex types.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element] The schema element
          # @param collector [ResultCollector] Collector for validation
          #   results
          # @return [void]
          def validate(xml_element, schema_element, collector)
            return unless schema_element

            type_def = resolve_element_type(schema_element)
            return unless type_def

            case type_def
            when Lutaml::Xsd::SimpleType
              validate_simple_type_content(xml_element, type_def, collector)
            when Lutaml::Xsd::ComplexType
              validate_complex_type_content(xml_element, type_def, collector)
            else
              # Handle built-in types
              validate_builtin_type(xml_element, type_def, collector)
            end
          end

          private

          # Resolve the type definition for an element
          #
          # @param schema_element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::SimpleType, Lutaml::Xsd::ComplexType, nil]
          def resolve_element_type(schema_element)
            # Check for inline type definition
            return schema_element.simple_type if
              schema_element.respond_to?(:simple_type) &&
                schema_element.simple_type

            return schema_element.complex_type if
              schema_element.respond_to?(:complex_type) &&
                schema_element.complex_type

            # Check for type reference
            if schema_element.respond_to?(:type) && schema_element.type
              # TODO: Resolve type from repository
              # For now, return the type reference as-is
              return schema_element.type
            end

            nil
          end

          # Validate simple type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param simple_type [Lutaml::Xsd::SimpleType] The simple type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_type_content(xml_element, simple_type,
                                           collector)
            value = xml_element.text_content

            # Validate base type if present
            if simple_type.respond_to?(:restriction) &&
                simple_type.restriction
              validate_restriction(value, simple_type.restriction,
                                   xml_element, collector)
            elsif simple_type.respond_to?(:list) && simple_type.list
              validate_list(value, simple_type.list, xml_element, collector)
            elsif simple_type.respond_to?(:union) && simple_type.union
              validate_union(value, simple_type.union, xml_element, collector)
            end
          end

          # Validate complex type content
          #
          # @param xml_element [XmlElement] The XML element
          # @param complex_type [Lutaml::Xsd::ComplexType] Complex type def
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_complex_type_content(xml_element, complex_type,
                                            collector)
            # Complex type validation is handled by:
            # - AttributeValidationRule for attributes
            # - ContentModelValidationRule for content model
            # This rule focuses on type-level constraints

            # Check for simple content
            if complex_type.respond_to?(:simple_content) &&
                complex_type.simple_content
              validate_simple_content(xml_element, complex_type.simple_content,
                                      collector)
            end
          end

          # Validate restriction facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_restriction(value, restriction, xml_element, collector)
            # Validate base type first
            if restriction.respond_to?(:base) && restriction.base
              validate_base_type(value, restriction.base, xml_element,
                                 collector)
            end

            # Validate facets
            validate_facets(value, restriction, xml_element, collector)
          end

          # Validate base type
          #
          # @param value [String] The value to validate
          # @param base_type [String] The base type name
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_base_type(value, base_type, xml_element, collector)
            # TODO: Implement base type validation
            # This should use BaseTypeValidator registry
            # For now, skip validation
          end

          # Validate facets
          #
          # @param value [String] The value to validate
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The XML element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_facets(value, restriction, xml_element, collector)
            # Check each facet type
            validate_pattern_facets(value, restriction, xml_element, collector)
            validate_length_facets(value, restriction, xml_element, collector)
            validate_range_facets(value, restriction, xml_element, collector)
            validate_enumeration_facets(value, restriction, xml_element,
                                        collector)
          end

          # Validate pattern facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_pattern_facets(value, restriction, xml_element,
                                      collector)
            return unless restriction.respond_to?(:pattern)

            patterns = Array(restriction.pattern)
            return if patterns.empty?

            patterns.each do |pattern|
              pattern_value = if pattern.respond_to?(:value)
                                pattern.value
                              else
                                pattern.to_s
                              end

              begin
                regex = Regexp.new(pattern_value)
                next if value.match?(regex)

                report_error(
                  collector,
                  code: "pattern_mismatch",
                  message: "Value '#{value}' does not match pattern " \
                           "'#{pattern_value}'",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    pattern: pattern_value,
                  },
                )
              rescue RegexpError => e
                report_warning(
                  collector,
                  code: "invalid_pattern",
                  message: "Invalid pattern in schema: #{e.message}",
                  location: xml_element.xpath,
                )
              end
            end
          end

          # Validate length facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_length_facets(value, restriction, xml_element,
                                     collector)
            value_length = value.length

            # Check exact length
            if restriction.respond_to?(:length) && restriction.length
              expected_length = restriction.length.value.to_i
              if value_length != expected_length
                report_error(
                  collector,
                  code: "length_mismatch",
                  message: "Value length #{value_length} does not equal " \
                           "required length #{expected_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    expected_length: expected_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check minimum length
            if restriction.respond_to?(:min_length) && restriction.min_length
              min_length = restriction.min_length.value.to_i
              if value_length < min_length
                report_error(
                  collector,
                  code: "min_length_violation",
                  message: "Value length #{value_length} is less than " \
                           "minimum #{min_length}",
                  location: xml_element.xpath,
                  context: {
                    value: value,
                    min_length: min_length,
                    actual_length: value_length,
                  },
                )
              end
            end

            # Check maximum length
            return unless restriction.respond_to?(:max_length) && restriction.max_length

            max_length = restriction.max_length.value.to_i
            return unless value_length > max_length

            report_error(
              collector,
              code: "max_length_violation",
              message: "Value length #{value_length} exceeds maximum " \
                       "#{max_length}",
              location: xml_element.xpath,
              context: {
                value: value,
                max_length: max_length,
                actual_length: value_length,
              },
            )
          end

          # Validate range facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_range_facets(value, restriction, xml_element, collector)
            # TODO: Implement min/max inclusive/exclusive validation
            # This requires parsing the value as the appropriate numeric type
          end

          # Validate enumeration facets
          #
          # @param value [String] The value
          # @param restriction [Lutaml::Xsd::RestrictionSimpleType] Restriction
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_enumeration_facets(value, restriction, xml_element,
                                          collector)
            return unless restriction.respond_to?(:enumeration)

            enumerations = Array(restriction.enumeration)
            return if enumerations.empty?

            allowed_values = enumerations.map do |enum|
              enum.respond_to?(:value) ? enum.value : enum.to_s
            end

            return if allowed_values.include?(value)

            report_error(
              collector,
              code: "enumeration_violation",
              message: "Value '#{value}' is not in enumeration",
              location: xml_element.xpath,
              context: {
                value: value,
                allowed_values: allowed_values,
              },
              suggestion: "Use one of: #{allowed_values.join(', ')}",
            )
          end

          # Validate list type
          #
          # @param value [String] The value
          # @param list [Lutaml::Xsd::List] The list definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_list(value, list, xml_element, collector)
            # TODO: Implement list validation
            # Lists are space-separated values of the item type
          end

          # Validate union type
          #
          # @param value [String] The value
          # @param union [Lutaml::Xsd::Union] The union definition
          # @param xml_element [XmlElement] The element
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_union(value, union, xml_element, collector)
            # TODO: Implement union validation
            # Value must match one of the member types
          end

          # Validate simple content
          #
          # @param xml_element [XmlElement] The element
          # @param simple_content [Lutaml::Xsd::SimpleContent] Simple content
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_simple_content(xml_element, simple_content, collector)
            # Simple content means element has text content and attributes
            # Validate the text content as a simple type
            if simple_content.respond_to?(:extension) &&
                simple_content.extension
              # Extension adds attributes to a simple type
              # Text content validation handled by base type
            elsif simple_content.respond_to?(:restriction) &&
                simple_content.restriction
              # Restriction constrains a simple type
              value = xml_element.text_content
              validate_restriction(value, simple_content.restriction,
                                   xml_element, collector)
            end
          end

          # Validate built-in type
          #
          # @param xml_element [XmlElement] The element
          # @param type_name [String] The type name
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_builtin_type(xml_element, type_name, collector)
            # TODO: Implement built-in type validation using BaseTypeValidator
            # For now, skip validation
          end
        end
      end
    end
  end
end

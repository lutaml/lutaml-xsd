# frozen_string_literal: true

require_relative "../validation_rule"

module Lutaml
  module Xsd
    module Validation
      module Rules
        # AttributeValidationRule validates element attributes
        #
        # This rule checks:
        # - Required attributes are present
        # - Attribute values match schema definitions
        # - No unexpected attributes exist
        # - Attribute types are valid
        #
        # Based on Jing validator attribute validation algorithm.
        #
        # @example Using the rule
        #   rule = AttributeValidationRule.new
        #   rule.validate(xml_element, schema_element, collector)
        #
        # @see docs/JING_ALGORITHM_PORTING_GUIDE.md Attribute Validation
        class AttributeValidationRule < ValidationRule
          # Rule category
          #
          # @return [Symbol] :constraint
          def category
            :constraint
          end

          # Rule description
          #
          # @return [String]
          def description
            "Validates element attributes against schema definitions"
          end

          # Validate element attributes
          #
          # Validates all attributes of an XML element against the schema
          # definition, checking presence of required attributes, validity
          # of values, and absence of unexpected attributes.
          #
          # @param xml_element [XmlElement] The XML element to validate
          # @param schema_element [Lutaml::Xsd::Element, Lutaml::Xsd::ComplexType]
          #   The schema definition
          # @param collector [ResultCollector] Collector for validation results
          # @return [void]
          def validate(xml_element, schema_element, collector)
            return unless schema_element

            schema_attributes = collect_schema_attributes(schema_element)
            xml_attributes = xml_element.attributes

            # Step 1: Check required attributes are present
            validate_required_attributes(xml_element, schema_attributes,
                                         xml_attributes, collector)

            # Step 2: Validate attribute values
            validate_attribute_values(xml_element, schema_attributes,
                                      xml_attributes, collector)

            # Step 3: Check for unexpected attributes
            validate_no_unexpected_attributes(xml_element, schema_attributes,
                                              xml_attributes, collector)
          end

          private

          # Collect all schema attributes from element or type definition
          #
          # @param schema_def [Lutaml::Xsd::Element, Lutaml::Xsd::ComplexType]
          #   Schema definition
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_schema_attributes(schema_def)
            attributes = []

            # For elements, get attributes from type
            if schema_def.is_a?(Lutaml::Xsd::Element)
              type_def = resolve_type(schema_def)
              return collect_schema_attributes(type_def) if type_def
            end

            # For complex types, collect attributes
            if schema_def.respond_to?(:attribute)
              attributes.concat(Array(schema_def.attribute))
            end

            # Handle attribute groups
            if schema_def.respond_to?(:attribute_group)
              Array(schema_def.attribute_group).each do |group|
                attributes.concat(expand_attribute_group(group))
              end
            end

            # Handle complex content
            if schema_def.respond_to?(:complex_content) &&
               schema_def.complex_content
              attributes.concat(
                collect_from_complex_content(schema_def.complex_content)
              )
            end

            # Handle simple content
            if schema_def.respond_to?(:simple_content) &&
               schema_def.simple_content
              attributes.concat(
                collect_from_simple_content(schema_def.simple_content)
              )
            end

            attributes
          end

          # Resolve type from element
          #
          # @param element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::ComplexType, nil]
          def resolve_type(element)
            return element.complex_type if element.respond_to?(:complex_type) &&
                                           element.complex_type

            # TODO: Resolve type reference from repository
            nil
          end

          # Expand attribute group reference
          #
          # @param group [Lutaml::Xsd::AttributeGroup] Attribute group
          # @return [Array<Lutaml::Xsd::Attribute>]
          def expand_attribute_group(group)
            return [] unless group.respond_to?(:attribute)

            Array(group.attribute)
          end

          # Collect attributes from complex content
          #
          # @param complex_content [Lutaml::Xsd::ComplexContent]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_complex_content(complex_content)
            attributes = []

            if complex_content.respond_to?(:extension) &&
               complex_content.extension
              ext = complex_content.extension
              attributes.concat(Array(ext.attribute)) if
                ext.respond_to?(:attribute)
            end

            if complex_content.respond_to?(:restriction) &&
               complex_content.restriction
              restr = complex_content.restriction
              attributes.concat(Array(restr.attribute)) if
                restr.respond_to?(:attribute)
            end

            attributes
          end

          # Collect attributes from simple content
          #
          # @param simple_content [Lutaml::Xsd::SimpleContent]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_simple_content(simple_content)
            attributes = []

            if simple_content.respond_to?(:extension) &&
               simple_content.extension
              ext = simple_content.extension
              attributes.concat(Array(ext.attribute)) if
                ext.respond_to?(:attribute)
            end

            if simple_content.respond_to?(:restriction) &&
               simple_content.restriction
              restr = simple_content.restriction
              attributes.concat(Array(restr.attribute)) if
                restr.respond_to?(:attribute)
            end

            attributes
          end

          # Validate required attributes are present
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_required_attributes(xml_element, schema_attrs,
                                           xml_attrs, collector)
            required = schema_attrs.select { |a| attribute_required?(a) }

            required.each do |schema_attr|
              attr_name = schema_attr.name
              found = xml_attrs.any? { |xa| xa.name == attr_name }

              next if found

              report_error(
                collector,
                code: "required_attribute_missing",
                message: "Required attribute '#{attr_name}' is missing",
                location: xml_element.xpath,
                context: {
                  attribute: attr_name,
                  element: xml_element.name
                },
                suggestion: "Add attribute: #{attr_name}=\"...\""
              )
            end
          end

          # Check if attribute is required
          #
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @return [Boolean]
          def attribute_required?(schema_attr)
            return false unless schema_attr.respond_to?(:use)

            schema_attr.use == "required"
          end

          # Validate attribute values
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_attribute_values(xml_element, schema_attrs, xml_attrs,
                                        collector)
            xml_attrs.each do |xml_attr|
              schema_attr = find_schema_attribute(schema_attrs, xml_attr)
              next unless schema_attr

              validate_attribute_value(xml_element, xml_attr, schema_attr,
                                       collector)
            end
          end

          # Find schema attribute definition for XML attribute
          #
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attr [XmlAttribute] XML attribute
          # @return [Lutaml::Xsd::Attribute, nil]
          def find_schema_attribute(schema_attrs, xml_attr)
            schema_attrs.find do |sa|
              sa.name == xml_attr.name &&
                (xml_attr.namespace_uri.nil? ||
                 sa.target_namespace == xml_attr.namespace_uri)
            end
          end

          # Validate single attribute value
          #
          # @param xml_element [XmlElement] The element
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_attribute_value(xml_element, xml_attr, schema_attr,
                                       collector)
            value = xml_attr.value

            # Check fixed value constraint
            if schema_attr.respond_to?(:fixed) && schema_attr.fixed
              unless value == schema_attr.fixed
                report_error(
                  collector,
                  code: "fixed_attribute_value_mismatch",
                  message: "Attribute '#{xml_attr.name}' must have fixed " \
                           "value '#{schema_attr.fixed}'",
                  location: xml_element.xpath,
                  context: {
                    attribute: xml_attr.name,
                    expected: schema_attr.fixed,
                    actual: value
                  }
                )
              end
              return
            end

            # Validate against type definition
            validate_attribute_type(xml_element, xml_attr, schema_attr,
                                    collector)
          end

          # Validate attribute type
          #
          # @param xml_element [XmlElement] The element
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_attribute_type(xml_element, xml_attr, schema_attr,
                                      collector)
            # TODO: Implement type validation for attributes
            # This should use BaseTypeValidator for built-in types
            # and SimpleTypeValidator for custom types
          end

          # Validate no unexpected attributes
          #
          # @param xml_element [XmlElement] The element
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attrs [Array<XmlAttribute>] XML attributes
          # @param collector [ResultCollector] Result collector
          # @return [void]
          def validate_no_unexpected_attributes(xml_element, schema_attrs,
                                                xml_attrs, collector)
            xml_attrs.each do |xml_attr|
              # Skip xmlns attributes
              next if xml_attr.name == "xmlns" ||
                      xml_attr.prefix == "xmlns"

              # Skip xsi attributes
              next if xml_attr.namespace_uri ==
                      "http://www.w3.org/2001/XMLSchema-instance"

              schema_attr = find_schema_attribute(schema_attrs, xml_attr)
              next if schema_attr

              # Check for wildcard (anyAttribute)
              next if has_any_attribute?(schema_attrs)

              report_error(
                collector,
                code: "unexpected_attribute",
                message: "Attribute '#{xml_attr.qualified_name}' is not " \
                         "allowed here",
                location: xml_element.xpath,
                context: {
                  attribute: xml_attr.qualified_name,
                  element: xml_element.name
                },
                suggestion: suggest_similar_attribute(xml_attr, schema_attrs)
              )
            end
          end

          # Check if schema allows any attribute (wildcard)
          #
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @return [Boolean]
          def has_any_attribute?(schema_attrs)
            # TODO: Check for anyAttribute in schema
            false
          end

          # Suggest similar attribute name
          #
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @return [String, nil]
          def suggest_similar_attribute(xml_attr, schema_attrs)
            return nil if schema_attrs.empty?

            # Simple suggestion based on available attributes
            attr_names = schema_attrs.map(&:name).compact
            return nil if attr_names.empty?

            "Did you mean one of: #{attr_names.join(', ')}?"
          end
        end
      end
    end
  end
end
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
          PROBE_SCHEMA = <<~XSD
            <xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
              <xs:complexType name="probe">
                <xs:anyAttribute namespace="##local"/>
              </xs:complexType>
            </xs:schema>
          XSD

          CONTENT_KINDS = %i[complex_content simple_content].freeze
          CONTENT_PART_KINDS = %i[extension restriction].freeze

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
          def validate(xml_element, schema_element, collector,
                       repository: nil)
            return unless schema_element

            schema_attributes =
              collect_schema_attributes(schema_element, repository)
            # Ref attributes resolve to the global declaration they
            # reference — the particle carries no name of its own.
            # The raw list stays for the required check (use lives on
            # the particle, not the declaration).
            resolved_attributes =
              resolve_schema_attributes(schema_attributes, repository)
            xml_attributes = xml_element.attributes
            wildcard = collect_any_attribute(schema_element, repository)

            # Step 1: Check required attributes are present
            validate_required_attributes(xml_element, schema_attributes,
                                         xml_attributes, collector)

            # Step 2: Validate attribute values
            validate_attribute_values(xml_element, resolved_attributes,
                                      xml_attributes, collector,
                                      repository: repository)

            # Step 3: Check for unexpected attributes
            validate_no_unexpected_attributes(xml_element,
                                              resolved_attributes,
                                              xml_attributes, collector,
                                              wildcard: wildcard,
                                              repository: repository)
          end

          private

          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>] the
          #   declarations ref particles point at (unresolvable refs and
          #   direct declarations pass through).
          def resolve_schema_attributes(schema_attrs, repository)
            schema_attrs.map do |attr|
              ref = attr.ref.to_s
              next attr if ref.empty?

              local = ref.split(":").last
              repository&.resolve_attribute(local, nil) || attr
            end
          end

          # Collect all schema attributes from element or type definition
          #
          # @param schema_def [Lutaml::Xsd::Element, Lutaml::Xsd::ComplexType]
          #   Schema definition
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_schema_attributes(schema_def, repository = nil)
            attributes = []

            # For elements, get attributes from type
            if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              type_def = resolve_type(schema_def, repository)
              return collect_schema_attributes(type_def, repository) if type_def
            end

            # For complex types, collect attributes
            attributes.concat(Array(schema_def.attribute)) if schema_def.attribute

            # Handle attribute groups
            if schema_def.attribute_group
              Array(schema_def.attribute_group).each do |group|
                attributes.concat(expand_attribute_group(group, repository))
              end
            end

            # Handle complex content
            if schema_def.complex_content
              attributes.concat(
                collect_from_complex_content(
                  schema_def.complex_content, repository
                ),
              )
              part = Array(schema_def.complex_content.extension).first ||
                Array(schema_def.complex_content.restriction).first
              # Base attributes flow through both derivations — a
              # restriction narrows them but cannot drop them (XSD 1.0
              # §3.4.2).
              attributes.concat(inherited_attributes(part.base, repository)) if part
            end

            # Handle simple content
            if schema_def.simple_content
              attributes.concat(
                collect_from_simple_content(
                  schema_def.simple_content, repository
                ),
              )
              part = Array(schema_def.simple_content.extension).first ||
                Array(schema_def.simple_content.restriction).first
              attributes.concat(inherited_attributes(part.base, repository)) if part
            end

            attributes
          end

          # The base type's attribute set flows into the derived type
          # through extension and restriction alike.
          #
          # @return [Array<Lutaml::Xml::Schema::Xsd::Attribute>]
          def inherited_attributes(base_name, repository)
            local = base_name.to_s.split(":").last
            return [] if local.to_s.empty?

            base = repository&.resolve_named_type(local)
            return [] unless base.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)

            collect_schema_attributes(base, repository)
          end

          # Resolve type from element
          #
          # @param element [Lutaml::Xsd::Element] Schema element
          # @return [Lutaml::Xsd::ComplexType, nil]
          def resolve_type(element, repository = nil)
            return element.complex_type if element.complex_type
            return nil unless element.type

            resolved = repository&.resolve_type(element)
            resolved if resolved.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
          end

          # Expand attribute group reference
          #
          # @param group [Lutaml::Xsd::AttributeGroup] Attribute group
          # @return [Array<Lutaml::Xsd::Attribute>]
          def expand_attribute_group(group, repository = nil, depth = 0)
            return [] if depth > 5

            attrs = Array(group.attribute)
            return attrs unless attrs.empty?

            local = (group.ref || group.name).to_s.split(":").last
            declaration = repository&.resolve_attribute_group(local)
            return [] unless declaration

            expand_attribute_group(declaration, repository, depth + 1)
          end

          # Collect attributes from complex content
          #
          # @param complex_content [Lutaml::Xsd::ComplexContent]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_complex_content(complex_content, repository = nil)
            collect_from_content(complex_content, repository)
          end

          # Collect attributes from simple content
          #
          # @param simple_content [Lutaml::Xsd::SimpleContent]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_simple_content(simple_content, repository = nil)
            collect_from_content(simple_content, repository)
          end

          # Extension and restriction shapes carry both attribute and
          # attributeGroup collections.
          #
          # @param content [Object]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Array<Lutaml::Xsd::Attribute>]
          def collect_from_content(content, repository)
            attributes = []

            %i[extension restriction].each do |shape|
              part = content.public_send(shape)
              next unless part

              attributes.concat(Array(part.attribute))
              Array(part.attribute_group).each do |group|
                attributes.concat(expand_attribute_group(group, repository))
              end
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
                  element: xml_element.name,
                },
                suggestion: "Add attribute: #{attr_name}=\"...\"",
              )
            end
          end

          # Check if attribute is required
          #
          # @param schema_attr [Lutaml::Xsd::Attribute] Schema attribute
          # @return [Boolean]
          def attribute_required?(schema_attr)
            return false unless schema_attr.use

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
                                        collector, repository: nil)
            xml_attrs.each do |xml_attr|
              schema_attr = find_schema_attribute(schema_attrs, xml_attr,
                                                  repository)
              next unless schema_attr

              validate_attribute_value(xml_element, xml_attr, schema_attr,
                                       collector)
            end
          end

          # Find schema attribute definition for XML attribute
          #
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @param xml_attr [XmlAttribute] XML attribute
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [Lutaml::Xsd::Attribute, nil]
          def find_schema_attribute(schema_attrs, xml_attr, repository = nil)
            schema_attrs.find do |sa|
              next false unless sa.name == xml_attr.name

              # Owner schema's target namespace for indexed (global)
              # declarations; nil reads as unqualified for locals.
              expected = repository&.target_namespace_for(sa)
              xml_attr.namespace_uri.nil? || expected == xml_attr.namespace_uri
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
            if schema_attr.fixed
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
                    actual: value,
                  },
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
          # @param wildcard [AnyAttribute, nil] xs:anyAttribute declaration
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [void]
          def validate_no_unexpected_attributes(xml_element, schema_attrs,
                                                xml_attrs, collector,
                                                wildcard: nil, repository: nil)
            xml_attrs.each do |xml_attr|
              # Skip xmlns attributes
              next if xml_attr.name == "xmlns" ||
                xml_attr.prefix == "xmlns"

              # Skip xsi attributes
              next if xml_attr.namespace_uri ==
                "http://www.w3.org/2001/XMLSchema-instance"

              schema_attr = find_schema_attribute(schema_attrs, xml_attr,
                                                  repository)
              next if schema_attr

              if wildcard &&
                  wildcard_permits_attribute?(wildcard, xml_element,
                                              xml_attr, repository)
                if wildcard.process_contents.to_s == "strict" &&
                    !attribute_declared?(xml_attr, repository)
                  report_error(
                    collector,
                    code: "wildcard_undeclared_attribute",
                    message: "Attribute '#{xml_attr.qualified_name}' " \
                             "matches xs:anyAttribute with " \
                             "processContents=strict but is not declared",
                    location: xml_element.xpath,
                    context: { attribute: xml_attr.qualified_name },
                  )
                end
                next
              end

              report_error(
                collector,
                code: "unexpected_attribute",
                message: "Attribute '#{xml_attr.qualified_name}' is not " \
                         "allowed here",
                location: xml_element.xpath,
                context: {
                  attribute: xml_attr.qualified_name,
                  element: xml_element.name,
                },
                suggestion: suggest_similar_attribute(xml_attr, schema_attrs),
              )
            end
          end

          # The xs:anyAttribute wildcard declared on this type, where the
          # parse layer exposes one (attribute groups and content-model
          # extension/restriction do). complexType-level wildcards are not
          # mapped upstream yet, so types carrying one keep the
          # pre-wildcard behavior for undeclared attributes.
          #
          # @param schema_def [Lutaml::Xml::Schema::Xsd::Element,
          #   Lutaml::Xsd::ComplexType, nil]
          # @param repository [SchemaDefinitionResolver, nil]
          # @return [AnyAttribute, nil]
          # Whether the loaded lutaml-model parses xs:anyAttribute on
          # complexType (the mapping landed after 0.8.121); probed once
          # with a minimal schema.
          def complex_type_wildcard_support?
            @complex_type_wildcard_support ||= begin
              probe = Lutaml::Xml::Schema::Xsd.parse(PROBE_SCHEMA)
              !probe.complex_type.first.any_attribute.nil?
            rescue StandardError
              false
            end
          end

          def collect_any_attribute(schema_def, repository = nil)
            if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::Element)
              type_def = resolve_type(schema_def, repository)
              return collect_any_attribute(type_def, repository) if type_def
            end
            return nil unless schema_def

            if schema_def.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType) &&
                complex_type_wildcard_support?
              wildcard = schema_def.any_attribute
              return wildcard if wildcard
            end

            Array(schema_def.attribute_group).each do |group|
              wildcard = Array(group.any_attribute).first
              return wildcard if wildcard
            end

            CONTENT_KINDS.each do |content_kind|
              content = schema_def.public_send(content_kind)
              next unless content

              CONTENT_PART_KINDS.each do |part_kind|
                part = Array(content.public_send(part_kind)).first
                next unless part

                wildcard = Array(part.any_attribute).first
                return wildcard if wildcard
              end
            end

            # The base type's wildcard flows into the derived type
            # through extension and restriction alike.
            base = derivation_base(schema_def, repository)
            return collect_any_attribute(base, repository) if base

            nil
          end

          # The named base type of the derivation shape, when present.
          #
          # @return [Lutaml::Xml::Schema::Xsd::ComplexType, nil]
          def derivation_base(schema_def, repository)
            CONTENT_KINDS.each do |content_kind|
              content = schema_def.public_send(content_kind)
              next unless content

              CONTENT_PART_KINDS.each do |part_kind|
                part = Array(content.public_send(part_kind)).first
                next unless part

                local = part.base.to_s.split(":").last
                next if local.to_s.empty?

                base = repository&.resolve_named_type(local)
                return base if base.is_a?(Lutaml::Xml::Schema::Xsd::ComplexType)
              end
            end

            nil
          end

          # Whether an xs:anyAttribute wildcard's namespace constraint
          # admits the attribute (attributes default to unqualified, so
          # ##local is the common admission).
          #
          # @return [Boolean]
          def wildcard_permits_attribute?(wildcard, parent, xml_attr,
                                          repository)
            ns = xml_attr.namespace_uri.to_s
            target = content_target_namespace(parent, repository).to_s
            case wildcard.namespace.to_s
            when "##any", ""
              true
            when "##other"
              !ns.empty? && ns != target
            when "##local"
              ns.empty?
            when "##targetNamespace"
              ns == target
            else
              # space-separated namespace list (##targetNamespace ##local
              # allowed)
              wildcard.namespace.to_s.split(/\s+/).any? do |entry|
                case entry
                when "##local" then ns.empty?
                when "##targetNamespace" then ns == target
                else entry == ns
                end
              end
            end
          end

          # Whether a strict-wildcard attribute resolves to a global
          # declaration in the repository.
          #
          # @return [Boolean]
          def attribute_declared?(xml_attr, repository)
            return true if repository.nil?

            !repository.resolve_attribute(xml_attr.name,
                                          xml_attr.namespace_uri).nil?
          end

          # Target namespace of the schema owning the parent's declaration.
          #
          # @return [String, nil]
          def content_target_namespace(parent, repository)
            return nil unless repository

            declaration = repository.resolve(parent.name,
                                             parent.namespace_uri)
            repository.target_namespace_for(declaration) if declaration
          end

          # Suggest similar attribute name
          #
          # @param xml_attr [XmlAttribute] XML attribute
          # @param schema_attrs [Array<Lutaml::Xsd::Attribute>] Schema attrs
          # @return [String, nil]
          def suggest_similar_attribute(_xml_attr, schema_attrs)
            return nil if schema_attrs.empty?

            # Simple suggestion based on available attributes
            attr_names = schema_attrs.filter_map(&:name)
            return nil if attr_names.empty?

            "Did you mean one of: #{attr_names.join(', ')}?"
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Builds Lutaml::Xml::Schema::Xsd::Attribute and XSD::AttributeGroup
      # instances from RNG attribute patterns.
      class AttributeBuilder
        Xsd = Lutaml::Xml::Schema::Xsd
        Inspector = PatternInspector

        def initialize(simple_type_builder:)
          @simple_type_builder = simple_type_builder
        end

        # Build an AttributeGroup from a list of attribute patterns.
        # The list may contain Rng::Attribute, occurrence-wrapped Attributes,
        # or Refs to other attribute groups.
        def build_group(name, attributes)
          xsd_attrs = []
          attr_group_refs = []

          attributes.each do |a|
            case a
            when Rng::Ref
              attr_group_refs << Xsd::AttributeGroup.new(ref: a.name)
            when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
              inner = Inspector.all_patterns(a).find { |p| p.is_a?(Rng::Attribute) }
              if inner
                converted = convert_attribute(inner)
                xsd_attrs << converted if converted
              end
            else
              converted = convert_attribute(a)
              xsd_attrs << converted if converted
            end
          end

          ag = Xsd::AttributeGroup.new(name: name, attribute: xsd_attrs)
          ag.attribute_group = attr_group_refs if attr_group_refs.any?
          ag
        end

        # Convert an Rng::Attribute to an XSD Attribute.
        def convert_attribute(rng_attr)
          name = Inspector.element_name(rng_attr)
          return nil unless name

          xsd_attr = Xsd::Attribute.new(name: name, use: "optional")

          child = Inspector.single_child(rng_attr)
          if child
            assign_attribute_type(xsd_attr, child)
          else
            xsd_attr.type = "xs:string"
          end

          if rng_attr.documentation
            xsd_attr.annotation = Xsd::Annotation.new(
              documentation: [
                Xsd::Documentation.new(content: rng_attr.documentation.to_s),
              ],
            )
          end

          xsd_attr
        end

        private

        def assign_attribute_type(xsd_attr, child)
          case child
          when Rng::Data
            xsd_attr.type = @simple_type_builder.data_type_name(child)
          when Rng::Value
            xsd_attr.type = child.type ? "xs:#{child.type}" : "xs:string"
          when Rng::Text
            xsd_attr.type = "xs:string"
          when Rng::Ref
            xsd_attr.type = child.name
          when Rng::Choice
            values = @simple_type_builder.collect_values(child)
            if values.any?
              st = @simple_type_builder.build_enum(nil, values)
              xsd_attr.simple_type = st
            else
              xsd_attr.type = "xs:string"
            end
          end
        end
      end
    end
  end
end

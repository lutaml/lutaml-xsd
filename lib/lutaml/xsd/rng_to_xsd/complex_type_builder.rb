# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Builds Lutaml::Xml::Schema::Xsd::ComplexType from particle and
      # attribute patterns. Delegates particle conversion to ParticleConverter
      # and attribute conversion to AttributeBuilder.
      class ComplexTypeBuilder
        Xsd = Lutaml::Xml::Schema::Xsd
        Inspector = PatternInspector

        def initialize(particle_converter:, attribute_builder:, define_map:,
                       schema_sink:)
          @particle_converter = particle_converter
          @attribute_builder = attribute_builder
          @define_map = define_map
          @schema_sink = schema_sink
        end

        # Build a named ComplexType from particle and attribute patterns.
        def build(name, particles, attributes, mixed)
          actual_particles, particle_attr_refs = classify(particles)

          xsd_attrs = []
          xsd_attr_group_refs = []

          attributes.each do |a|
            if a.is_a?(Rng::Ref)
              xsd_attr_group_refs << Xsd::AttributeGroup.new(ref: a.name)
            elsif a.is_a?(Rng::Optional) || a.is_a?(Rng::ZeroOrMore) || a.is_a?(Rng::OneOrMore)
              inner = Inspector.all_patterns(a).find { |p| p.is_a?(Rng::Attribute) }
              if inner
                converted = @attribute_builder.convert_attribute(inner)
                xsd_attrs << converted if converted
              end
            else
              converted = @attribute_builder.convert_attribute(a)
              xsd_attrs << converted if converted
            end
          end

          xsd_attr_group_refs.concat(particle_attr_refs)

          particle_children = actual_particles.filter_map do |p|
            @particle_converter.extract_inline_element(p) ||
              @particle_converter.convert(p, :particle)
          end

          ct = Xsd::ComplexType.new(
            name: name,
            mixed: mixed,
            attribute: xsd_attrs,
          )
          ct.attribute_group = xsd_attr_group_refs if xsd_attr_group_refs.any?

          @particle_converter.assign_content_model(ct, particle_children)
          ct
        end

        # Build a Group (with Sequence or single child) from particle patterns.
        def build_group(name, particles)
          actual_particles, = classify(particles)

          children = actual_particles.filter_map { |p| @particle_converter.convert(p, :particle) }
          return nil if children.empty?

          if children.size == 1
            case children.first
            when Xsd::Sequence
              return Xsd::Group.new(name: name, sequence: children.first)
            when Xsd::Choice
              return Xsd::Group.new(name: name, choice: children.first)
            end
          end

          Xsd::Group.new(
            name: name,
            sequence: @particle_converter.wrap_in_sequence(children),
          )
        end

        # Split particles into actual particles and attribute-group refs.
        def classify(particles)
          actual = []
          refs = []
          particles.each do |p|
            if p.is_a?(Rng::Ref) && Inspector.ref_resolves_to_attribute_group?(p, @define_map)
              refs << Xsd::AttributeGroup.new(ref: p.name)
            else
              actual << p
            end
          end
          [actual, refs]
        end
      end
    end
  end
end

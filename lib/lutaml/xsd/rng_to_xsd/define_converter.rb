# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Converts each Rng::Define into one of: SimpleType, AttributeGroup,
      # Group, named ComplexType, or top-level Element (with optional Group
      # alias when the define name differs from the element name).
      #
      # Maintains the conversion cache and cycle guard so it's safe to call
      # repeatedly from collaborators.
      class DefineConverter
        Xsd = Lutaml::Xml::Schema::Xsd
        Inspector = PatternInspector

        def initialize(define_map:, simple_type_builder:, complex_type_builder:,
                       particle_converter:, naming_service:, schema_sink:)
          @define_map = define_map
          @simple_type_builder = simple_type_builder
          @complex_type_builder = complex_type_builder
          @particle_converter = particle_converter
          @naming_service = naming_service
          @schema_sink = schema_sink

          @results = {}
          @converting = Set.new
        end

        attr_reader :results

        # Convert all defines in the map.
        def convert_all
          @define_map.each_key { |name| convert(name) }
        end

        # Convert one define by name, caching the result hash.
        def convert(name)
          return @results[name] if @results.key?(name)
          return {} if @converting.include?(name)

          @converting.add(name)
          define = @define_map[name]
          unless define
            @converting.delete(name)
            return {}
          end

          result = build_result(name, define)
          @results[name] = result
          @converting.delete(name)
          result
        end

        private

        def build_result(name, define)
          patterns = Inspector.unwrap_group(define)
          particles, attributes, data_patterns = classify_children(patterns)
          has_elements = particles.any? { |p| contains_element?(p) }

          if attributes.empty? && !has_elements && data_patterns.any?
            build_simple_type_result(name, data_patterns)
          elsif attributes.any? && !has_elements && particles.empty?
            build_attribute_group_result(name, attributes)
          elsif has_elements || particles.any?
            build_particle_result(name, particles, attributes)
          else
            {}
          end
        end

        def classify_children(patterns)
          particles = []
          attributes = []
          data_patterns = []

          patterns.each do |p|
            case p
            when Rng::Attribute
              attributes << p
            when Rng::Data, Rng::Value, Rng::List, Rng::Text
              data_patterns << p
            when Rng::Ref
              if Inspector.ref_resolves_to_attribute_group?(p, @define_map)
                attributes << p
              else
                particles << p
              end
            else
              if Inspector.attribute_like_pattern?(p, @define_map)
                attributes << p
              else
                particles << p
              end
            end
          end

          [particles, attributes, data_patterns]
        end

        def build_simple_type_result(name, data_patterns)
          st = @simple_type_builder.build_from_patterns(name, data_patterns)
          return {} unless st

          @schema_sink.call(:simple_type, st)
          { simple_type: st }
        end

        def build_attribute_group_result(name, attributes)
          ag = AttributeBuilder
            .new(simple_type_builder: @simple_type_builder)
            .build_group(name, attributes)
          @schema_sink.call(:attribute_group, ag)
          { attribute_group: ag }
        end

        def build_particle_result(name, particles, attributes)
          single_elem = Inspector.extract_single_element(particles)
          xsd_elem = single_elem ? @particle_converter.convert_element(single_elem) : nil

          if single_elem && attributes.empty?
            build_pure_element_result(name, single_elem, xsd_elem)
          elsif attributes.any?
            build_named_complex_type_result(name, particles, attributes)
          else
            build_group_result(name, particles)
          end
        end

        def build_pure_element_result(name, single_elem, xsd_elem)
          elem_name = Inspector.element_name(single_elem)

          if @naming_service.should_promote?(name, elem_name) && xsd_elem
            promote_element_to_schema(name, elem_name, xsd_elem)
          elsif xsd_elem
            grp = Xsd::Group.new(
              name: name,
              sequence: Xsd::Sequence.new(element: [xsd_elem]),
            )
            @schema_sink.call(:group, grp)
            { group: grp }
          else
            {}
          end
        end

        def promote_element_to_schema(name, elem_name, xsd_elem)
          @schema_sink.call(:element, xsd_elem)

          if xsd_elem.complex_type
            ct = xsd_elem.complex_type
            ct.name = "#{elem_name}_type"
            @schema_sink.call(:complex_type, ct)
            xsd_elem.type = "#{elem_name}_type"
            xsd_elem.complex_type = nil
          end

          result = { element: xsd_elem }

          if name != elem_name
            grp = Xsd::Group.new(
              name: name,
              sequence: Xsd::Sequence.new(
                element: [Xsd::Element.new(ref: elem_name)],
              ),
            )
            @schema_sink.call(:group, grp)
            result[:group] = grp
          end

          result
        end

        def build_named_complex_type_result(name, particles, attributes)
          ct = @complex_type_builder.build(name, particles, attributes, false)
          @schema_sink.call(:complex_type, ct)
          { complex_type: ct }
        end

        def build_group_result(name, particles)
          grp = @complex_type_builder.build_group(name, particles)
          return {} unless grp

          @schema_sink.call(:group, grp)
          { group: grp }
        end

        def contains_element?(pattern)
          Inspector.contains_element?(pattern, @define_map, @results)
        end
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Converts RNG particle patterns (element, choice, sequence, interleave,
      # optional, zeroOrMore, oneOrMore, mixed, ref) into XSD particle objects.
      # Owns the central dispatch and per-pattern handlers. Does not touch
      # ComplexType construction (that's ComplexTypeBuilder).
      class ParticleConverter
        Xsd = Lutaml::Xml::Schema::Xsd
        Inspector = PatternInspector

        # resolver must respond to #call(name) -> result hash (for Ref handling)
        # define_map is the static name -> Rng::Define lookup
        # define_results_view is a proc/callable returning the current result
        #   hash (so contains_element? can see what's been promoted to top-level)
        # schema_sink is a callable that takes an XSD object and adds it to
        #   the schema being built.
        def initialize(simple_type_builder:, attribute_builder:,
                       define_resolver:, define_map:, define_results_view:,
                       schema_sink:)
          @simple_type_builder = simple_type_builder
          @attribute_builder = attribute_builder
          @define_resolver = define_resolver
          @define_map = define_map
          @define_results_view = define_results_view
          @schema_sink = schema_sink
        end

        # Central pattern dispatch. Returns an XSD model object or nil.
        def convert(pattern, context = :particle)
          case pattern
          when Rng::Element
            convert_element(pattern)
          when Rng::Attribute
            @attribute_builder.convert_attribute(pattern)
          when Rng::Choice
            convert_choice(pattern, context)
          when Rng::Group
            convert_group(pattern)
          when Rng::Interleave
            convert_interleave(pattern)
          when Rng::Optional
            convert_occurrence(pattern, "0", "1")
          when Rng::ZeroOrMore
            convert_occurrence(pattern, "0", "unbounded")
          when Rng::OneOrMore
            convert_occurrence(pattern, "1", "unbounded")
          when Rng::Mixed
            convert_mixed(pattern)
          when Rng::Ref
            convert_ref(pattern, context)
          when Rng::Data
            convert_data(pattern, context)
          when Rng::Value
            convert_value(pattern, context)
          when Rng::Empty
            nil
          when Rng::List
            convert_list(pattern)
          end
        end

        def convert_element(rng_elem)
          name = Inspector.element_name(rng_elem)
          return nil unless name

          patterns = Inspector.all_patterns(rng_elem)

          particle_children = []
          attribute_children = []
          attr_group_refs = []
          has_mixed = false
          data_child = nil

          patterns.each do |p|
            case p
            when Rng::Attribute
              attribute_children << p
            when Rng::Ref
              if ref_resolves_to_simple_type?(p)
                data_child = p
              elsif Inspector.ref_resolves_to_attribute_group?(p, @define_map)
                attr_group_refs << Xsd::AttributeGroup.new(ref: p.name)
              else
                particle_children << p
              end
            when Rng::Mixed
              has_mixed = true
              particle_children.concat(Inspector.all_patterns(p))
            when Rng::Data, Rng::Value
              data_child = p
            when Rng::Text
              data_child ||= p
            when Rng::Empty
              next
            else
              particle_children << p
            end
          end

          has_mixed = true if !has_mixed && data_child.nil? &&
            attribute_children.any? && particle_children.any?

          xsd_elem = Xsd::Element.new(name: name)
          attach_annotation(xsd_elem, rng_elem.documentation)

          if attribute_children.empty? && attr_group_refs.empty? &&
              particle_children.empty? && data_child
            assign_simple_type_to_element(xsd_elem, data_child)
          elsif attribute_children.any? || attr_group_refs.any? || particle_children.any?
            attach_complex_content(
              xsd_elem, particle_children, attribute_children,
              attr_group_refs, data_child, has_mixed
            )
          elsif data_child.is_a?(Rng::Text)
            xsd_elem.type = "xs:string"
          end

          xsd_elem
        end

        def assign_simple_type_to_element(xsd_elem, data_child)
          case data_child
          when Rng::Text
            xsd_elem.type = "xs:string"
          when Rng::Data
            xsd_elem.type = @simple_type_builder.data_type_name(data_child)
          when Rng::Value
            xsd_elem.type = data_child.type ? "xs:#{data_child.type}" : "xs:string"
          when Rng::Ref
            xsd_elem.type = data_child.name
          end
        end

        # If a particle is an inline element eligible for extraction to a
        # top-level global element, convert it and return a ref element.
        # Otherwise nil — caller falls back to convert_pattern.
        def extract_inline_element(particle)
          min_occurs = nil
          max_occurs = nil

          case particle
          when Rng::Optional
            min_occurs = "0"
            max_occurs = "1"
            inner = Inspector.all_patterns(particle).first
          when Rng::ZeroOrMore
            min_occurs = "0"
            max_occurs = "unbounded"
            inner = Inspector.all_patterns(particle).first
          when Rng::OneOrMore
            min_occurs = "1"
            max_occurs = "unbounded"
            inner = Inspector.all_patterns(particle).first
          when Rng::Element
            inner = particle
          else
            return nil
          end

          return nil unless inner.is_a?(Rng::Element)

          elem_name = Inspector.element_name(inner)
          return nil unless elem_name

          patterns = Inspector.all_patterns(inner)
          content_patterns = patterns.reject { |pat| pat.is_a?(Rng::Attribute) }
          return nil unless content_patterns.any?
          return nil unless content_patterns.all? { |pat| Inspector.structural_ref_pattern?(pat) }

          xsd_elem = convert_element(inner)
          return nil unless xsd_elem

          @schema_sink.call(xsd_elem)

          ref_elem = Xsd::Element.new(ref: elem_name)
          ref_elem.min_occurs = min_occurs if min_occurs
          ref_elem.max_occurs = max_occurs if max_occurs
          ref_elem
        end

        # Assign a content model (sequence/choice/all) to a ComplexType
        # from a list of XSD particle children.
        def assign_content_model(ctype, children)
          return if children.empty?

          elements = []
          choices = []
          groups = []
          sequences = []

          children.each do |child|
            case child
            when Xsd::Element
              elements << child
            when Xsd::Choice
              choices << child
            when Xsd::Group
              groups << child
            when Xsd::Sequence
              sequences << child
            when Xsd::All
              ctype.all = child
              return
            end
          end

          if children.size == 1
            case children.first
            when Xsd::Sequence
              ctype.sequence = children.first
              return
            when Xsd::Choice
              ctype.choice = children.first
              return
            end
          end

          ctype.sequence = Xsd::Sequence.new(
            element: elements,
            choice: choices,
            group: groups,
            sequence: sequences,
          )
        end

        def wrap_in_sequence(children)
          elements = []
          choices = []
          groups = []
          sequences = []

          children.each do |child|
            case child
            when Xsd::Element
              elements << child
            when Xsd::Choice
              choices << child
            when Xsd::Group, Xsd::All
              groups << child
            when Xsd::Sequence
              sequences << child
            end
          end

          Xsd::Sequence.new(
            element: elements,
            choice: choices,
            group: groups,
            sequence: sequences,
          )
        end

        private

        def attach_annotation(xsd_obj, documentation)
          return unless documentation

          xsd_obj.annotation = Xsd::Annotation.new(
            documentation: [
              Xsd::Documentation.new(content: documentation.to_s),
            ],
          )
        end

        def attach_complex_content(xsd_elem, particle_children, attribute_children,
                                   attr_group_refs, data_child, has_mixed)
          xsd_attrs = attribute_children.filter_map { |a| @attribute_builder.convert_attribute(a) }
          ct = Xsd::ComplexType.new(
            name: nil,
            mixed: has_mixed,
            attribute: xsd_attrs,
          )
          ct.attribute_group = attr_group_refs if attr_group_refs.any?

          if data_child && particle_children.empty?
            type_name = @simple_type_builder.resolve_data_type(data_child)
            sc = Xsd::SimpleContent.new(
              extension: Xsd::ExtensionSimpleContent.new(
                base: type_name,
                attribute: xsd_attrs,
              ),
            )
            ct.simple_content = sc
            ct.attribute = []
          else
            converted = particle_children.filter_map do |p|
              extract_inline_element(p) || convert(p, :particle)
            end
            assign_content_model(ct, converted)
          end

          @schema_sink.call(ct) if ct.name
          xsd_elem.complex_type = ct
        end

        def ref_resolves_to_simple_type?(ref)
          return false unless ref.is_a?(Rng::Ref) && ref.name

          result = @define_resolver.call(ref.name)
          result&.key?(:simple_type)
        end

        def convert_choice(choice, context)
          children = Inspector.all_patterns(choice)
          return nil if children.empty?

          if context == :data
            convert_choice_data(choice, children)
          else
            convert_choice_particle(children)
          end
        end

        def convert_choice_data(choice, children)
          values = @simple_type_builder.collect_values(choice)
          if values.any? && values.all? { |v| v[:value] }
            return @simple_type_builder.build_enum(nil, values)
          end

          types = children.filter_map { |p| @simple_type_builder.build(nil, p) }
          return nil if types.empty?

          if types.size == 1
            types.first
          else
            Xsd::SimpleType.new(union: Xsd::Union.new(simple_type: types))
          end
        end

        def convert_choice_particle(children)
          element_children = []
          has_non_element = false

          children.each do |p|
            if Inspector.contains_element?(p, @define_map, @define_results_view.call)
              xsd = convert(p, :particle)
              element_children << xsd if xsd
            else
              has_non_element = true
            end
          end

          return nil if element_children.empty?

          result = build_choice_result(element_children)
          if has_non_element && Inspector.supports_occurrences?(result)
            result.min_occurs = "0"
            result.max_occurs = "1"
          end
          result
        end

        def build_choice_result(element_children)
          return element_children.first if element_children.size == 1

          Xsd::Choice.new(
            element: element_children.select { |c| c.is_a?(Xsd::Element) },
            sequence: element_children.select { |c| c.is_a?(Xsd::Sequence) },
            choice: element_children.select { |c| c.is_a?(Xsd::Choice) },
            group: element_children.select { |c| c.is_a?(Xsd::Group) },
          )
        end

        def convert_group(group)
          children = Inspector.all_patterns(group)
          return nil if children.empty?

          xsd_children = children.filter_map { |p| convert(p, :particle) }
          return nil if xsd_children.empty?

          if xsd_children.size == 1
            xsd_children.first
          else
            wrap_in_sequence(xsd_children)
          end
        end

        def convert_interleave(interleave)
          children = Inspector.all_patterns(interleave)
          return nil if children.empty?

          xsd_children = children.filter_map { |p| convert(p, :particle) }
          return nil if xsd_children.empty?

          if xsd_children.size == 1
            xsd_children.first
          else
            Xsd::All.new(element: xsd_children)
          end
        end

        def convert_occurrence(wrapper, min, max)
          children = Inspector.all_patterns(wrapper)
          return nil if children.empty?

          xsd_children = children.filter_map { |p| convert(p, :particle) }
          return nil if xsd_children.empty?

          if xsd_children.size == 1
            child = xsd_children.first
            if Inspector.supports_occurrences?(child)
              child.min_occurs = min
              child.max_occurs = max
            end
            child
          else
            seq = wrap_in_sequence(xsd_children)
            seq.min_occurs = min
            seq.max_occurs = max
            seq
          end
        end

        def convert_mixed(mixed)
          children = Inspector.all_patterns(mixed)
          return nil if children.empty?

          child = children.first
          return nil unless child

          convert(child, :particle)
        end

        def convert_ref(ref, context)
          name = ref.name
          return nil unless name

          result = @define_resolver.call(name)

          if context == :data
            return ref_data_result(result, name)
          end

          ref_particle_result(result, name)
        end

        def ref_data_result(result, name)
          return nil unless result&.key?(:simple_type)

          Xsd::SimpleType.new(
            restriction: Xsd::RestrictionSimpleType.new(base: name),
          )
        end

        def ref_particle_result(result, name)
          if result[:element]
            elem_name = result[:element].is_a?(Xsd::Element) ? result[:element].name : name
            Xsd::Element.new(ref: elem_name)
          elsif result[:attribute_group]
            Xsd::AttributeGroup.new(ref: name)
          elsif result[:simple_type]
            nil
          else
            # result[:group], result[:complex_type], or unknown -> group ref
            Xsd::Group.new(ref: name)
          end
        end

        def convert_data(data, context)
          return unless context == :data

          @simple_type_builder.build_from_data(nil, data)
        end

        def convert_value(value, context)
          return unless context == :data

          @simple_type_builder.build_from_value(nil, value)
        end

        def convert_list(list_pattern)
          inner = Inspector.all_patterns(list_pattern).first
          item_type = inner ? @simple_type_builder.resolve_data_type(inner) : "xs:string"
          Xsd::SimpleType.new(
            list: Xsd::List.new(item_type: item_type),
          )
        end
      end
    end
  end
end

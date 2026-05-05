# frozen_string_literal: true

require "set"

module Lutaml
  module Xsd
    # Converts an Rng::Grammar object to an Lutaml::Xml::Schema::Xsd::Schema.
    # Follows the same mapping logic as jing-trang's RNG-to-XSD conversion.
    class RngToXsdConverter
      # @param grammar [Rng::Grammar] The parsed RNG grammar
      # @param file_path [String] Original file path (for error messages)
      def initialize(grammar, file_path: nil)
        @grammar = grammar
        @file_path = file_path

        # Build define name -> Rng::Define lookup
        @define_map = build_define_map(grammar)

        # Track converted defines to prevent infinite recursion
        @converting = Set.new

        # Cache: define_name -> { group:, attribute_group:, simple_type:, complex_type: }
        @define_results = {}
      end

      # Convert the grammar to an XSD Schema
      # @return [Lutaml::Xml::Schema::Xsd::Schema]
      def convert
        schema = Lutaml::Xml::Schema::Xsd::Schema.new
        # Set target_namespace only if it's a real value (not uninitialized)
        ns = @grammar.ns
        schema.target_namespace = ns unless ns.nil? || ns.is_a?(Lutaml::Model::UninitializedClass)

        # Phase 1: Convert all defines
        convert_all_defines(schema)

        # Phase 2: Convert start elements and top-level elements
        convert_start_elements(schema)
        convert_grammar_elements(schema)

        schema
      end

      private

      # Resolve a value that might be Lutaml::Model::UninitializedClass to nil or a string
      def resolve_string(value)
        return nil if value.nil? || value.is_a?(Lutaml::Model::UninitializedClass)
        value.to_s
      end

      # Collect all pattern children from an RNG container node
      # Returns an array of non-nil pattern objects
      def get_all_patterns(container)
        patterns = []
        pattern_types.each do |attr|
          next unless container.respond_to?(attr)

          children = container.send(attr)
          next if children.nil?

          if children.is_a?(Array)
            patterns.concat(children.compact)
          else
            patterns << children
          end
        end
        patterns
      end

      # The attribute names that hold pattern children
      def pattern_types
        %w[element ref choice group interleave mixed optional zeroOrMore
           oneOrMore text empty value data list notAllowed attribute]
      end

      # Build define name -> Define lookup from grammar (including divs)
      def build_define_map(grammar)
        map = {}
        collect_defines(grammar, map)
        map
      end

      def collect_defines(container, map)
        (container.define || []).each do |d|
          map[d.name] = d if d.name
        end
        (container.div || []).each { |div| collect_defines(div, map) }
      end

      # Phase 1: Convert all named defines
      def convert_all_defines(schema)
        @define_map.each_key do |name|
          convert_define(name, schema)
        end
      end

      # Convert a single define by name, caching results
      def convert_define(name, schema)
        return @define_results[name] if @define_results.key?(name)

        # Cycle guard
        if @converting.include?(name)
          # For circular refs, return empty - the ref will emit a group ref
          return {}
        end

        @converting.add(name)
        define = @define_map[name]
        unless define
          @converting.delete(name)
          return {}
        end

        result = {}
        patterns = get_all_patterns(define)

        # Classify children
        particles = []
        attributes = []
        data_patterns = []

        patterns.each do |p|
          case p
          when Rng::Attribute
            attributes << p
          when Rng::Data, Rng::Value, Rng::List
            data_patterns << p
          else
            particles << p
          end
        end

        has_elements = particles.any? { |p| contains_element?(p) }

        if attributes.empty? && !has_elements && data_patterns.any?
          # Pure data define -> SimpleType
          st = build_simple_type_from_patterns(name, data_patterns)
          if st
            schema&.simple_type(st)
            result[:simple_type] = st
          end
        elsif attributes.any? && !has_elements && particles.empty?
          # Pure attribute define -> AttributeGroup
          ag = build_attribute_group(name, attributes)
          schema&.attribute_group(ag)
          result[:attribute_group] = ag
        elsif has_elements || particles.any?
          if attributes.any?
            # Both particles and attributes -> named ComplexType
            ct = build_complex_type(name, particles, attributes, false)
            schema&.complex_type(ct)
            result[:complex_type] = ct
          else
            # Pure particle define -> Group
            grp = build_group(name, particles)
            if grp
              schema&.group(grp)
              result[:group] = grp
            end
          end
        end

        @define_results[name] = result
        @converting.delete(name)
        result
      end

      # Check if a pattern (possibly nested in wrappers) contains an element
      def contains_element?(pattern)
        case pattern
        when Rng::Element
          true
        when Rng::Choice, Rng::Group, Rng::Interleave, Rng::Mixed,
             Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
          get_all_patterns(pattern).any? { |p| contains_element?(p) }
        when Rng::Ref
          # Look up the define
          define = @define_map[pattern.name]
          return false unless define

          get_all_patterns(define).any? { |p| contains_element?(p) }
        else
          false
        end
      end

      # Check if a pattern contains data/value (no elements, no text mixed in)
      def contains_data?(pattern)
        case pattern
        when Rng::Data, Rng::Value
          true
        when Rng::Text
          false
        when Rng::Choice, Rng::Group, Rng::Interleave
          children = get_all_patterns(pattern)
          children.any? { |p| contains_data?(p) } &&
            children.none? { |p| contains_element?(p) }
        when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
          get_all_patterns(pattern).any? { |p| contains_data?(p) }
        when Rng::Ref
          define = @define_map[pattern.name]
          return false unless define

          get_all_patterns(define).any? { |p| contains_data?(p) }
        else
          false
        end
      end

      # Build a SimpleType from data/value patterns
      def build_simple_type_from_patterns(name, patterns)
        if patterns.size == 1
          build_simple_type(name, patterns.first)
        else
          # Multiple data patterns -> union
          types = patterns.filter_map { |p| build_simple_type(nil, p) }
          return nil if types.empty?

          if types.size == 1
            types.first.name = name
            types.first
          else
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              union: Lutaml::Xml::Schema::Xsd::Union.new(
                simple_type: types
              )
            )
          end
        end
      end

      # Build a SimpleType from a single data/value/list pattern
      def build_simple_type(name, pattern)
        case pattern
        when Rng::Data
          build_simple_type_from_data(name, pattern)
        when Rng::Value
          build_simple_type_from_value(name, pattern)
        when Rng::List
          build_simple_type_from_list(name, pattern)
        when Rng::Text
          Lutaml::Xml::Schema::Xsd::SimpleType.new(
            name: name,
            restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
              base: "xs:string"
            )
          )
        when Rng::Choice
          # Choice of values -> enumeration facets
          values = collect_values(pattern)
          if values.any?
            build_enum_simple_type(name, values)
          else
            # Union of child types
            child_types = get_all_patterns(pattern).filter_map { |p| build_simple_type(nil, p) }
            return nil if child_types.empty?

            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              union: Lutaml::Xml::Schema::Xsd::Union.new(
                simple_type: child_types
              )
            )
          end
        when Rng::Ref
          # Reference to a named type
          result = convert_define(pattern.name, nil)
          if result[:simple_type]
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              name: name,
              restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
                base: pattern.name
              )
            )
          end
        end
      end

      # Build SimpleType from Rng::Data
      def build_simple_type_from_data(name, data)
        type_name = data_type_name(data)
        restriction = Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(base: type_name)

        # Map params to facets
        (data.param || []).each do |param|
          facet = build_facet(param)
          restriction.send(facet.first, facet.last) if facet
        end

        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: restriction
        )
      end

      # Build SimpleType from Rng::Value (single enumeration)
      def build_simple_type_from_value(name, value)
        type_name = value.type ? "xs:#{value.type}" : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
            base: type_name,
            enumeration: [
              Lutaml::Xml::Schema::Xsd::Enumeration.new(value: value.value)
            ]
          )
        )
      end

      # Build SimpleType from Rng::List
      def build_simple_type_from_list(name, list_pattern)
        inner = get_all_patterns(list_pattern).first
        item_type = inner ? resolve_data_type(inner) : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          list: Lutaml::Xml::Schema::Xsd::List.new(item_type: item_type)
        )
      end

      # Build a SimpleType with enumeration facets from a list of values
      def build_enum_simple_type(name, values)
        type_name = values.first[:type] || "xs:string"
        enums = values.map do |v|
          Lutaml::Xml::Schema::Xsd::Enumeration.new(value: v[:value])
        end
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          name: name,
          restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
            base: type_name,
            enumeration: enums
          )
        )
      end

      # Collect all Value patterns from a choice tree
      def collect_values(pattern)
        case pattern
        when Rng::Value
          [{ type: pattern.type ? "xs:#{pattern.type}" : nil, value: pattern.value }]
        when Rng::Choice
          get_all_patterns(pattern).flat_map { |p| collect_values(p) }
        else
          []
        end
      end

      # Resolve a data/value pattern to an XSD type name string
      def resolve_data_type(pattern)
        case pattern
        when Rng::Data
          data_type_name(pattern)
        when Rng::Value
          pattern.type ? "xs:#{pattern.type}" : "xs:string"
        when Rng::Text
          "xs:string"
        else
          "xs:string"
        end
      end

      # Get the XSD type name for a Data pattern
      def data_type_name(data)
        lib = resolve_string(data.datatypeLibrary) || resolve_string(@grammar.datatypeLibrary) || ""
        type = data.type || "string"

        if lib.empty? || lib.include?("XMLSchema-datatypes") || lib.include?("XMLSchema")
          # Map NOTATION to QName per jing-trang logic
          type = "QName" if type == "NOTATION"
          "xs:#{type}"
        else
          warn "Warning: Non-XSD datatype library '#{lib}' in #{@file_path}, " \
               "using type name as-is: #{type}"
          "xs:#{type}"
        end
      end

      # Build an XSD facet from an RNG Param
      # Returns [collection_name, facet_object] or nil
      def build_facet(param)
        case param.name
        when "minInclusive"
          [:min_inclusive, Lutaml::Xml::Schema::Xsd::MinInclusive.new(value: param.value)]
        when "maxInclusive"
          [:max_inclusive, Lutaml::Xml::Schema::Xsd::MaxInclusive.new(value: param.value)]
        when "minExclusive"
          [:min_exclusive, Lutaml::Xml::Schema::Xsd::MinExclusive.new(value: param.value.to_i)]
        when "maxExclusive"
          [:max_exclusive, Lutaml::Xml::Schema::Xsd::MaxExclusive.new(value: param.value.to_i)]
        when "pattern"
          [:pattern, Lutaml::Xml::Schema::Xsd::Pattern.new(value: param.value)]
        when "totalDigits"
          [:total_digits, Lutaml::Xml::Schema::Xsd::TotalDigits.new(value: param.value)]
        when "fractionDigits"
          [:fraction_digits, Lutaml::Xml::Schema::Xsd::FractionDigits.new(value: param.value)]
        when "minLength"
          [:min_length, Lutaml::Xml::Schema::Xsd::MinLength.new(value: param.value.to_i)]
        when "maxLength"
          [:max_length, Lutaml::Xml::Schema::Xsd::MaxLength.new(value: param.value.to_i)]
        when "length"
          [:length, Lutaml::Xml::Schema::Xsd::Length.new(value: param.value.to_i)]
        when "whiteSpace"
          [:white_space, Lutaml::Xml::Schema::Xsd::WhiteSpace.new(value: param.value)]
        else
          warn "Warning: Unknown RNG param '#{param.name}' in #{@file_path}"
          nil
        end
      end

      # Build an AttributeGroup from attribute patterns
      def build_attribute_group(name, attributes)
        xsd_attrs = attributes.filter_map { |a| convert_attribute_pattern(a) }
        Lutaml::Xml::Schema::Xsd::AttributeGroup.new(
          name: name,
          attribute: xsd_attrs
        )
      end

      # Build a Group (with Sequence) from particle patterns
      def build_group(name, particles)
        children = particles.filter_map { |p| convert_pattern(p, :particle) }
        return nil if children.empty?

        # Classify children into elements, choices, groups, sequences
        elements = []
        choices = []
        groups = []
        sequences = []

        children.each do |child|
          case child
          when Lutaml::Xml::Schema::Xsd::Element
            elements << child
          when Lutaml::Xml::Schema::Xsd::Choice
            choices << child
          when Lutaml::Xml::Schema::Xsd::Group
            groups << child
          when Lutaml::Xml::Schema::Xsd::Sequence
            sequences << child
          when Lutaml::Xml::Schema::Xsd::All
            # Wrap All in a group reference isn't possible; add as-is
            groups << child
          end
        end

        # If there's exactly one child and it's already a sequence/choice, use it directly
        if children.size == 1
          child = children.first
          case child
          when Lutaml::Xml::Schema::Xsd::Sequence
            return Lutaml::Xml::Schema::Xsd::Group.new(
              name: name,
              sequence: child
            )
          when Lutaml::Xml::Schema::Xsd::Choice
            return Lutaml::Xml::Schema::Xsd::Group.new(
              name: name,
              choice: child
            )
          end
        end

        # Wrap in a sequence
        seq = Lutaml::Xml::Schema::Xsd::Sequence.new(
          element: elements,
          choice: choices,
          group: groups,
          sequence: sequences
        )
        Lutaml::Xml::Schema::Xsd::Group.new(
          name: name,
          sequence: seq
        )
      end

      # Build a named ComplexType from particle and attribute patterns
      def build_complex_type(name, particles, attributes, mixed)
        xsd_attrs = attributes.filter_map { |a| convert_attribute_pattern(a) }

        # Build content model from particles
        particle_children = particles.filter_map { |p| convert_pattern(p, :particle) }

        ct = Lutaml::Xml::Schema::Xsd::ComplexType.new(
          name: name,
          mixed: mixed,
          attribute: xsd_attrs
        )

        assign_content_model(ct, particle_children)
        ct
      end

      # Assign the appropriate content model (sequence/choice/all) to a ComplexType
      def assign_content_model(ct, children)
        return if children.empty?

        elements = []
        choices = []
        groups = []
        sequences = []

        children.each do |child|
          case child
          when Lutaml::Xml::Schema::Xsd::Element
            elements << child
          when Lutaml::Xml::Schema::Xsd::Choice
            choices << child
          when Lutaml::Xml::Schema::Xsd::Group
            groups << child
          when Lutaml::Xml::Schema::Xsd::Sequence
            sequences << child
          when Lutaml::Xml::Schema::Xsd::All
            ct.all = child
            return
          end
        end

        if children.size == 1
          child = children.first
          case child
          when Lutaml::Xml::Schema::Xsd::Sequence
            ct.sequence = child
            return
          when Lutaml::Xml::Schema::Xsd::Choice
            ct.choice = child
            return
          end
        end

        ct.sequence = Lutaml::Xml::Schema::Xsd::Sequence.new(
          element: elements,
          choice: choices,
          group: groups,
          sequence: sequences
        )
      end

      # Phase 2a: Convert start elements
      def convert_start_elements(schema)
        (@grammar.start || []).each do |start|
          pattern = get_start_pattern(start)
          next unless pattern

          case pattern
          when Rng::Element
            xsd_elem = convert_element_pattern(pattern)
            schema.element(xsd_elem) if xsd_elem
          when Rng::Ref
            # Start references a define - the define was already converted
            result = @define_results[pattern.name]
            if result&.dig(:complex_type)
              # Create a root element whose type is the named complex type
              xsd_elem = Lutaml::Xml::Schema::Xsd::Element.new(
                name: pattern.name,
                type: pattern.name
              )
              schema.element(xsd_elem)
            elsif result&.dig(:group)
              # The group defines the root content - no extra element needed
            end
          end
        end
      end

      # Get the single pattern child from a Start
      def get_start_pattern(start)
        pattern_types.each do |attr|
          next unless start.respond_to?(attr)
          child = start.send(attr)
          return child if child && !child.is_a?(Array)
        end
        nil
      end

      # Phase 2b: Convert top-level elements from grammar
      def convert_grammar_elements(schema)
        (@grammar.element || []).each do |rng_elem|
          xsd_elem = convert_element_pattern(rng_elem)
          schema.element(xsd_elem) if xsd_elem
        end
      end

      # Central pattern dispatch
      # @return [Object, nil] An XSD model object, or nil for empty/notAllowed
      def convert_pattern(pattern, context = :particle)
        case pattern
        when Rng::Element
          convert_element_pattern(pattern)
        when Rng::Attribute
          convert_attribute_pattern(pattern)
        when Rng::Choice
          convert_choice_pattern(pattern, context)
        when Rng::Group
          convert_group_pattern(pattern)
        when Rng::Interleave
          convert_interleave_pattern(pattern)
        when Rng::Optional
          convert_occurrence_pattern(pattern, "0", "1")
        when Rng::ZeroOrMore
          convert_occurrence_pattern(pattern, "0", "unbounded")
        when Rng::OneOrMore
          convert_occurrence_pattern(pattern, "1", "unbounded")
        when Rng::Mixed
          convert_mixed_pattern(pattern)
        when Rng::Ref
          convert_ref_pattern(pattern, context)
        when Rng::Data
          convert_data_pattern(pattern, context)
        when Rng::Value
          convert_value_pattern(pattern, context)
        when Rng::Text
          convert_text_pattern(context)
        when Rng::Empty
          nil
        when Rng::List
          convert_list_pattern(pattern)
        else
          nil
        end
      end

      # Convert an RNG element to an XSD element
      def convert_element_pattern(rng_elem)
        name = element_name(rng_elem)
        return nil unless name

        patterns = get_all_patterns(rng_elem)

        # Classify children
        particle_children = []
        attribute_children = []
        has_mixed = false
        data_child = nil

        patterns.each do |p|
          case p
          when Rng::Attribute
            attribute_children << p
          when Rng::Mixed
            has_mixed = true
            particle_children.concat(get_all_patterns(p))
          when Rng::Data, Rng::Value
            data_child = p
          when Rng::Text
            data_child = p unless data_child
          when Rng::Empty
            # no content
          else
            particle_children << p
          end
        end

        xsd_elem = Lutaml::Xml::Schema::Xsd::Element.new(name: name)

        # Add documentation if present
        if rng_elem.documentation
          xsd_elem.annotation = Lutaml::Xml::Schema::Xsd::Annotation.new(
            documentation: [
              Lutaml::Xml::Schema::Xsd::Documentation.new(
                content: rng_elem.documentation.to_s
              )
            ]
          )
        end

        if attribute_children.empty? && particle_children.empty? && data_child
          # Simple content element
          assign_simple_type_to_element(xsd_elem, data_child)
        elsif attribute_children.any? || particle_children.any?
          # Complex content element
          xsd_attrs = attribute_children.filter_map { |a| convert_attribute_pattern(a) }
          ct = Lutaml::Xml::Schema::Xsd::ComplexType.new(
            mixed: has_mixed,
            attribute: xsd_attrs
          )

          # If there's also a data child, use simpleContent
          if data_child && particle_children.empty?
            type_name = resolve_data_type(data_child)
            sc = Lutaml::Xml::Schema::Xsd::SimpleContent.new(
              extension: Lutaml::Xml::Schema::Xsd::ExtensionSimpleContent.new(
                base: type_name,
                attribute: xsd_attrs
              )
            )
            ct.simple_content = sc
            ct.attribute = []
          else
            converted = particle_children.filter_map { |p| convert_pattern(p, :particle) }
            assign_content_model(ct, converted)
          end

          xsd_elem.complex_type = ct
        elsif data_child.is_a?(Rng::Text)
          xsd_elem.type = "xs:string"
        end

        xsd_elem
      end

      # Assign a simple type to an element (inline or via type reference)
      def assign_simple_type_to_element(xsd_elem, data_child)
        case data_child
        when Rng::Text
          xsd_elem.type = "xs:string"
        when Rng::Data
          xsd_elem.type = data_type_name(data_child)
        when Rng::Value
          xsd_elem.type = data_child.type ? "xs:#{data_child.type}" : "xs:string"
        end
      end

      # Convert an RNG attribute to an XSD attribute
      def convert_attribute_pattern(rng_attr)
        name = element_name(rng_attr)
        return nil unless name

        xsd_attr = Lutaml::Xml::Schema::Xsd::Attribute.new(
          name: name,
          use: "optional"
        )

        # Determine type from child pattern
        child = get_attribute_child(rng_attr)
        if child
          case child
          when Rng::Data
            xsd_attr.type = data_type_name(child)
          when Rng::Value
            xsd_attr.type = child.type ? "xs:#{child.type}" : "xs:string"
          when Rng::Text
            xsd_attr.type = "xs:string"
          when Rng::Ref
            # Reference to a simple type
            xsd_attr.type = child.name
          when Rng::Choice
            # Choice of values -> inline simple type with enumeration
            values = collect_values(child)
            if values.any?
              st = build_enum_simple_type(nil, values)
              xsd_attr.simple_type = st
            else
              xsd_attr.type = "xs:string"
            end
          end
        else
          xsd_attr.type = "xs:string"
        end

        # Add documentation
        if rng_attr.documentation
          xsd_attr.annotation = Lutaml::Xml::Schema::Xsd::Annotation.new(
            documentation: [
              Lutaml::Xml::Schema::Xsd::Documentation.new(
                content: rng_attr.documentation.to_s
              )
            ]
          )
        end

        xsd_attr
      end

      # Get the single pattern child from an Attribute
      def get_attribute_child(attr)
        pattern_types.each do |type_name|
          next unless attr.respond_to?(type_name)
          child = attr.send(type_name)
          return child if child && !child.is_a?(Array)
        end
        nil
      end

      # Extract element/attribute name from attr_name or name.value
      def element_name(node)
        name = node.attr_name
        name = node.name&.value if name.nil? || name.empty?
        name
      end

      # Convert a choice pattern
      def convert_choice_pattern(choice, context)
        children = get_all_patterns(choice)
        return nil if children.empty?

        if context == :data
          # Data context -> enumeration or union
          values = collect_values(choice)
          if values.any? && values.all? { |v| v[:value] }
            return build_enum_simple_type(nil, values)
          end

          types = children.filter_map { |p| build_simple_type(nil, p) }
          return nil if types.empty?

          if types.size == 1
            types.first
          else
            Lutaml::Xml::Schema::Xsd::SimpleType.new(
              union: Lutaml::Xml::Schema::Xsd::Union.new(simple_type: types)
            )
          end
        else
          # Particle context -> XSD Choice
          xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
          return nil if xsd_children.empty?

          if xsd_children.size == 1
            return xsd_children.first
          end

          elements = xsd_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Element) }
          sequences = xsd_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Sequence) }
          choices = xsd_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Choice) }
          groups = xsd_children.select { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Group) }

          Lutaml::Xml::Schema::Xsd::Choice.new(
            element: elements,
            sequence: sequences,
            choice: choices,
            group: groups
          )
        end
      end

      # Convert a group pattern -> Sequence
      def convert_group_pattern(group)
        children = get_all_patterns(group)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        wrap_in_sequence(xsd_children)
      end

      # Convert an interleave pattern -> All or Sequence
      def convert_interleave_pattern(interleave)
        children = get_all_patterns(interleave)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        # Use xs:all if all children are simple elements
        if xsd_children.all? { |c| c.is_a?(Lutaml::Xml::Schema::Xsd::Element) }
          Lutaml::Xml::Schema::Xsd::All.new(element: xsd_children)
        else
          wrap_in_sequence(xsd_children)
        end
      end

      # Convert an occurrence wrapper (optional, zeroOrMore, oneOrMore)
      def convert_occurrence_pattern(wrapper, min, max)
        children = get_all_patterns(wrapper)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        if xsd_children.size == 1
          child = xsd_children.first
          # Set occurrences on the child
          if child.respond_to?(:min_occurs=)
            child.min_occurs = min
            child.max_occurs = max
          end
          child
        else
          # Multiple children -> wrap in sequence with occurrences
          seq = wrap_in_sequence(xsd_children)
          seq.min_occurs = min
          seq.max_occurs = max
          seq
        end
      end

      # Convert a mixed pattern
      def convert_mixed_pattern(mixed)
        children = get_all_patterns(mixed)
        return nil if children.empty?

        xsd_children = children.filter_map { |p| convert_pattern(p, :particle) }
        return nil if xsd_children.empty?

        # Return the children; the caller (convert_element_pattern) handles mixed=true
        if xsd_children.size == 1
          xsd_children.first
        else
          wrap_in_sequence(xsd_children)
        end
      end

      # Convert a ref pattern
      def convert_ref_pattern(ref, context)
        name = ref.name
        return nil unless name

        # Ensure the define is converted
        result = convert_define(name, nil)

        if context == :data
          # Data context - reference to a simple type
          if result[:simple_type]
            return Lutaml::Xml::Schema::Xsd::SimpleType.new(
              restriction: Lutaml::Xml::Schema::Xsd::RestrictionSimpleType.new(
                base: name
              )
            )
          end
          return nil
        end

        # Particle context
        if result[:group]
          Lutaml::Xml::Schema::Xsd::Group.new(ref: name)
        elsif result[:attribute_group]
          # Attribute groups are not particles - return nil in particle context.
          # The parent define should handle attributes separately.
          nil
        elsif result[:complex_type]
          # Reference to a complex type - used as element type
          # This should be handled by the caller
          nil
        elsif result[:simple_type]
          # Reference to a simple type in particle context
          # This can happen when a define is used in both contexts
          nil
        else
          # Unknown ref - emit a group ref as fallback
          Lutaml::Xml::Schema::Xsd::Group.new(ref: name)
        end
      end

      # Convert a data pattern in particle context
      def convert_data_pattern(data, context)
        if context == :data
          build_simple_type_from_data(nil, data)
        else
          # In particle context, data doesn't produce a particle
          # It should be handled by the parent element
          nil
        end
      end

      # Convert a value pattern in particle context
      def convert_value_pattern(value, context)
        if context == :data
          build_simple_type_from_value(nil, value)
        else
          nil
        end
      end

      # Convert a text pattern in particle context
      def convert_text_pattern(context)
        # Text in particle context doesn't produce a visible XSD artifact
        # The parent element will get type="xs:string"
        nil
      end

      # Convert a list pattern
      def convert_list_pattern(list_pattern)
        inner = get_all_patterns(list_pattern).first
        item_type = inner ? resolve_data_type(inner) : "xs:string"
        Lutaml::Xml::Schema::Xsd::SimpleType.new(
          list: Lutaml::Xml::Schema::Xsd::List.new(item_type: item_type)
        )
      end

      # Wrap multiple children in a Sequence
      def wrap_in_sequence(children)
        elements = []
        choices = []
        groups = []
        sequences = []

        children.each do |child|
          case child
          when Lutaml::Xml::Schema::Xsd::Element
            elements << child
          when Lutaml::Xml::Schema::Xsd::Choice
            choices << child
          when Lutaml::Xml::Schema::Xsd::Group
            groups << child
          when Lutaml::Xml::Schema::Xsd::Sequence
            sequences << child
          when Lutaml::Xml::Schema::Xsd::All
            # Can't nest all directly; wrap in a group
            groups << child
          end
        end

        Lutaml::Xml::Schema::Xsd::Sequence.new(
          element: elements,
          choice: choices,
          group: groups,
          sequence: sequences
        )
      end
    end
  end
end

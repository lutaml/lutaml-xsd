# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Pure-function helpers for inspecting Rng pattern trees.
      # Stateless: every method takes the inputs it needs and returns a value.
      # Extracted from RngToXsdConverter so the same inspection logic can be
      # shared by every collaborator without copy/paste.
      class PatternInspector
        # Readers that any pattern-container RNG node may expose. Subset varies
        # by class: Rng::Attribute lacks :element and :attribute; Rng::Start
        # lacks :attribute. Filter via #defined_readers_for instead of probing
        # with public_send and rescuing NoMethodError.
        PATTERN_TYPE_READERS = %i[
          element
          ref
          choice
          group
          interleave
          mixed
          optional
          zeroOrMore
          oneOrMore
          text
          empty
          value
          data
          list
          notAllowed
          attribute
        ].freeze

        # Resolve a value that might be Lutaml::Model::UninitializedClass.
        def self.resolve_string(value)
          return nil if value.nil? || value.is_a?(Lutaml::Model::UninitializedClass)

          value.to_s
        end

        # Collect all pattern children from an RNG container node.
        def self.all_patterns(container)
          patterns = []
          defined_readers_for(container).each do |reader|
            children = container.public_send(reader)
            next if children.nil?
            next if children.is_a?(Lutaml::Model::UninitializedClass)

            if children.is_a?(Array)
              patterns.concat(children.compact)
            else
              patterns << children
            end
          end
          patterns
        end

        # Readers from PATTERN_TYPE_READERS that the given node's class
        # actually defines. Cached per class to avoid repeated reflection.
        def self.defined_readers_for(node)
          klass = node.class
          @defined_readers_cache ||= {}
          @defined_readers_cache[klass] ||= PATTERN_TYPE_READERS.select do |r|
            klass.method_defined?(r)
          end
        end

        # Extract element/attribute name from attr_name or name.value.
        def self.element_name(node)
          name = node.attr_name if node.is_a?(Rng::Element) || node.is_a?(Rng::Attribute)
          if (name.nil? || name.empty?) && node.is_a?(Rng::Element)
            name_val = node.name
            name = name_val.to_s if name_val
          end
          name
        end

        # True if the XSD model supports minOccurs/maxOccurs attributes.
        def self.supports_occurrences?(obj)
          obj.is_a?(Lutaml::Xml::Schema::Xsd::Element) ||
            obj.is_a?(Lutaml::Xml::Schema::Xsd::Sequence) ||
            obj.is_a?(Lutaml::Xml::Schema::Xsd::Choice) ||
            obj.is_a?(Lutaml::Xml::Schema::Xsd::All) ||
            obj.is_a?(Lutaml::Xml::Schema::Xsd::Group)
        end

        # Single-pattern container readers used by Attribute and Start:
        # returns the first non-array, non-nil, non-Uninitialized child.
        def self.single_child(node)
          defined_readers_for(node).each do |reader|
            child = node.public_send(reader)
            if child && !child.is_a?(Array) && !child.is_a?(Lutaml::Model::UninitializedClass)
              return child
            end
          end
          nil
        end

        # Unwrap occurrence wrappers (Optional/ZeroOrMore/OneOrMore/Mixed)
        # to reach the inner Rng::Element, if any.
        def self.unwrap_to_element(pattern)
          case pattern
          when Rng::Element
            pattern
          when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore, Rng::Mixed
            children = all_patterns(pattern)
            return nil unless children.length == 1

            unwrap_to_element(children.first)
          end
        end

        # If particles contains exactly one element (possibly wrapped),
        # return the bare Rng::Element.
        def self.extract_single_element(particles)
          return nil unless particles.length == 1

          unwrap_to_element(particles.first)
        end

        # Recursively check if a pattern tree contains an element anywhere.
        # `define_map` and `define_results` are passed so Refs can be resolved.
        def self.contains_element?(pattern, define_map, define_results)
          case pattern
          when Rng::Element
            true
          when Rng::Choice, Rng::Group, Rng::Interleave, Rng::Mixed,
               Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
            all_patterns(pattern).any? do |p|
              contains_element?(p, define_map, define_results)
            end
          when Rng::Ref
            define = define_map[pattern.name]
            return true unless define

            return true if define_results[pattern.name]&.key?(:element)

            all_patterns(define).any? do |p|
              contains_element?(p, define_map, define_results)
            end
          else
            false
          end
        end

        # True if pattern contains data/value (no elements, no text mixed in).
        def self.contains_data?(pattern, define_map)
          case pattern
          when Rng::Data, Rng::Value
            true
          when Rng::Choice, Rng::Group, Rng::Interleave
            children = all_patterns(pattern)
            children.any? { |p| contains_data?(p, define_map) } &&
              children.none? { |p| contains_element?(p, define_map, {}) }
          when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
            all_patterns(pattern).any? { |p| contains_data?(p, define_map) }
          when Rng::Ref
            define = define_map[pattern.name]
            return false unless define

            all_patterns(define).any? { |p| contains_data?(p, define_map) }
          else
            false
          end
        end

        # True if a pattern is attribute-like: an Attribute, an occurrence
        # wrapper around an attribute, or a Ref that resolves to an attr group.
        def self.attribute_like_pattern?(pattern, define_map)
          case pattern
          when Rng::Attribute
            true
          when Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore
            all_patterns(pattern).any? { |c| attribute_like_pattern?(c, define_map) }
          when Rng::Ref
            ref_resolves_to_attribute_group?(pattern, define_map)
          else
            false
          end
        end

        # True if a Ref points to a define whose children are all
        # attribute-like (no particles).
        def self.ref_resolves_to_attribute_group?(ref, define_map)
          return false unless ref.is_a?(Rng::Ref) && ref.name

          define = define_map[ref.name]
          return attribute_group_name?(ref.name) unless define

          patterns = unwrap_group(define)
          patterns.all? { |p| attribute_like_pattern?(p, define_map) }
        end

        # Convention-based fallback when a Ref's define is missing
        # (e.g., unresolved includes).
        def self.attribute_group_name?(name)
          name.end_with?("Attributes", "Id")
        end

        # Unwrap a single Group child, otherwise return the define's patterns.
        def self.unwrap_group(define)
          patterns = all_patterns(define)
          if patterns.length == 1 && patterns.first.is_a?(Rng::Group)
            patterns = all_patterns(patterns.first)
          end
          patterns
        end

        # Recursively check if a pattern tree consists entirely of Rng::Ref
        # instances, possibly nested in structural wrappers.
        def self.structural_ref_pattern?(pattern)
          case pattern
          when Rng::Ref
            true
          when Rng::Choice, Rng::Group, Rng::Interleave,
               Rng::Optional, Rng::ZeroOrMore, Rng::OneOrMore, Rng::Mixed
            children = all_patterns(pattern)
            children.any? && children.all? { |c| structural_ref_pattern?(c) }
          else
            false
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    module RngToXsd
      # Owns element-name collision detection and single-element promotion
      # decisions. A define that wraps a single Rng::Element may be promoted
      # to a top-level xs:element — except when multiple defines wrap elements
      # with the same name. In that case, all colliding defines become
      # xs:group with inline elements.
      class NamingService
        Inspector = PatternInspector

        def initialize(define_map)
          @define_map = define_map
          @collisions = build_collisions
        end

        # Should the define wrapping `define_name` (which contains a single
        # element with `elem_name`) be promoted to a top-level element?
        def should_promote?(define_name, elem_name)
          return false unless define_name && elem_name

          @collisions[elem_name]&.length.to_i <= 1
        end

        private

        # Map element_name -> list of define_names that wrap elements with
        # that name. Defines with > 1 entry in their list are in collision.
        def build_collisions
          map = {}
          @define_map.each_key do |name|
            define = @define_map[name]
            patterns = Inspector.unwrap_group(define)

            particles = patterns.reject do |p|
              p.is_a?(Rng::Attribute) ||
                p.is_a?(Rng::Data) || p.is_a?(Rng::Value) ||
                p.is_a?(Rng::List) || p.is_a?(Rng::Text) ||
                (p.is_a?(Rng::Ref) &&
                  Inspector.ref_resolves_to_attribute_group?(p, @define_map)) ||
                Inspector.attribute_like_pattern?(p, @define_map)
            end

            single = Inspector.extract_single_element(particles)
            next unless single

            elem_name = Inspector.element_name(single)
            next unless elem_name

            (map[elem_name] ||= []) << name
          end
          map
        end
      end
    end
  end
end

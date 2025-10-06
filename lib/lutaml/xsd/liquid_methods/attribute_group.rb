# frozen_string_literal: true

require_relative "resolved_element_order"

module Lutaml
  module Xsd
    module LiquidMethods
      module AttributeGroup
        include Model::Serialize
        include ResolvedElementOrder

        def used_by
          @__root.complex_type.select { |type| find_used_by(type) }
        end

        def attribute_elements(array = [])
          object_element_order.each_with_object(array) do |child, object|
            case child
            when Xsd::AttributeGroup then child.attribute_elements(object)
            when Xsd::Attribute then object << child
            end
          end
        end

        def find_used_by(object)
          object.resolved_element_order.any? do |child|
            if child.is_a?(Xsd::AttributeGroup)
              child.ref == name
            else
              find_used_by(child)
            end
          end
        end

        private

        def object_element_order
          return resolved_element_order unless ref

          @__root.attribute_group.find { |group| group.name == ref }&.resolved_element_order
        end
      end
    end
  end
end

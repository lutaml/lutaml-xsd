# frozen_string_literal: true

require_relative "resolved_element_order"

module Lutaml
  module Xsd
    module LiquidMethods
      module ComplexType
        include Lutaml::Model::Liquefiable
        include ResolvedElementOrder

        def used_by
          raw_elements = @__root.group.map(&:elements)
          raw_elements.concat(@__root.element)
          raw_elements.select { |el| el.type == name }
        end

        def attribute_elements(array = [])
          array.concat(attribute)
          array.concat(attribute_group.flat_map(&:attribute_elements))
          array
        end

        def child_elements(array = [])
          resolved_element_order.each_with_object(array) do |child, storage|
            child.child_elements(storage) if child.respond_to?(:child_elements)
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
      end
    end
  end
end

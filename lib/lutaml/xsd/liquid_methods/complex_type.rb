# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module ComplexType

        def used_by
          root_complex_types = @__root.complex_type.reject { |ct| ct == self }
          raw_elements = @__root.group.map(&:child_elements).flatten
          raw_elements.concat(@__root.element)
          raw_elements.concat(root_complex_types.map(&:child_elements).flatten)
          raw_elements.select { |el| el.type == name }
        end

        def attribute_elements(array = [])
          array.concat(attribute)
          attribute_group.flat_map { |group| group.attribute_elements(array) }
          simple_content&.attribute_elements(array)
          array
        end

        def child_elements(array = [])
          resolved_element_order.each do |child|
            if child.is_a?(Xsd::Element)
              array << child
            elsif child.respond_to?(:child_elements)
              child.child_elements(array)
            end
          end
          array
        end

        def find_elements_used(element_name)
          resolved_element_order.any? do |child|
            if child.is_a?(Xsd::Element)
              child.ref == element_name
            elsif child.respond_to?(:find_elements_used)
              child.find_elements_used(element_name)
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
      end
    end
  end
end

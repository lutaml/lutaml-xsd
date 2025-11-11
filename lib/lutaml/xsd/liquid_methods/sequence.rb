# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Sequence
        def child_elements(array = [])
          resolved_element_order.each do |child|
            if child.is_a?(Element)
              array << child
            elsif child.respond_to?(:child_elements)
              child.child_elements(array)
            end
          end
          array
        end

        def find_elements_used(element_name)
          resolved_element_order.any? do |child|
            if child.is_a?(Element)
              child.ref == element_name
            elsif child.respond_to?(:find_elements_used)
              child.find_elements_used(element_name)
            end
          end
        end
      end
    end
  end
end

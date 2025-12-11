# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Group
        def child_elements(array = [])
          referenced_object.resolved_element_order.each do |child|
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

        def referenced_object
          return self if name

          @__root.group.find { |group| group.name == ref }
        end
      end
    end
  end
end

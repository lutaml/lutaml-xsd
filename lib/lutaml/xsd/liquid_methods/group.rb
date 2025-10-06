# frozen_string_literal: true

require_relative "resolved_element_order"

module Lutaml
  module Xsd
    module LiquidMethods
      module Group
        include Model::Serialize
        include ResolvedElementOrder

        def child_elements(array = [])
          resolved_element_order.each do |child|
            if child.is_a?(Xsd::Element)
              array << child
            elsif child.respond_to?(:child_elements)
              child.child_elements(array)
            end
          end
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
      end
    end
  end
end

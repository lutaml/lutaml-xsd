# frozen_string_literal: true

require_relative "resolved_element_order"

module Lutaml
  module Xsd
    module LiquidMethods
      module Choice
        include Lutaml::Model::Liquefiable
        include ResolvedElementOrder

        def child_elements(array = [])
          resolved_element_order.each_with_object(array) do |child, storage|
            child.child_elements(storage) if child.respond_to?(:child_elements)
          end
        end
      end
    end
  end
end

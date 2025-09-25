# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module ResolvedElementOrder
        ELEMENT_ORDER_IGNORABLE = %w[import include].freeze

        def resolved_element_order
          element_order.each_with_object(element_order.dup) do |element, array|
            next delete_deletables(array, element) if deletable?(element)

            update_element_array(array, element)
          end
        end

        private

        def deletable?(instance)
          instance.text? ||
            ELEMENT_ORDER_IGNORABLE.include?(instance.name)
        end

        def delete_deletables(array, instance)
          array.delete_if { |ins| ins == instance }
        end

        def update_element_array(array, instance)
          index = 0
          array.each_with_index do |element, i|
            next unless element == instance

            method_name = ::Lutaml::Model::Utils.snake_case(instance.name)
            array[i] = Array(send(method_name))[index]
            index += 1
          end
        end
      end
    end
  end
end

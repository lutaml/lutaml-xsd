# frozen_string_literal: true

require_relative "resolved_element_order"

module Lutaml
  module Xsd
    module LiquidMethods
      module SimpleContent
        include Model::Serialize
        include ResolvedElementOrder

        def attribute_elements(array = [])
          extension.attribute_elements(array)
        end
      end
    end
  end
end

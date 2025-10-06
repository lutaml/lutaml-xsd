# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Extension
        include Model::Serialize

        def attribute_elements(array = [])
          array.concat(attribute)
          attribute_group.flat_map { |group| group.attribute_elements(array) }
          array
        end
      end
    end
  end
end

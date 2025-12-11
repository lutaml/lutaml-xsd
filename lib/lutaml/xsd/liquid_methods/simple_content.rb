# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module SimpleContent
        def attribute_elements(array = [])
          extension.attribute_elements(array)
        end

        def base_type
          base ||
            extension&.base ||
            restriction&.base
        end
      end
    end
  end
end

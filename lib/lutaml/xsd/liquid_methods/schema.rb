# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module AttributeGroup
        def elements_sorted_by_name
          element.sort_by(&:name)
        end

        def complex_types_sorted_by_name
          complex_type.sort_by(&:name)
        end

        def attribute_groups_sorted_by_name
          attribute_group.sort_by(&:name)
        end
      end
    end
  end
end

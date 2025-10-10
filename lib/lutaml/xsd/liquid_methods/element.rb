# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Element
        def used_by
          @__root.complex_type.select { |object| object.find_elements_used(name) }
        end

        def attributes
          referenced_complex_type.attribute_elements
        end

        def min_occurrences
          @min_occurs&.to_i || 1
        end

        def max_occurrences
          return "*" if @max_occurs == "unbounded"

          @max_occurs&.to_i || 1
        end

        def child_elements(array = [])
          referenced_complex_type&.child_elements(array)
        end

        def referenced_name
          referenced_object&.name
        end

        def referenced_type
          referenced_object&.type
        end

        def referenced_object
          return self if name

          @__root.element.find { |el| el.name == ref }
        end

        def referenced_complex_type
          @__root.complex_type.find { |type| type.name == referenced_type }
        end
      end
    end
  end
end

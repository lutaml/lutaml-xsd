# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Attribute
        def cardinality
          case use
          when "required" then "1"
          when "optional" then "0..1"
          end
        end

        def referenced_type
          @referenced_type ||= referenced_object&.type
        end

        def referenced_name
          @referenced_name ||= referenced_object&.name || ref
        end

        def referenced_object
          return self if name

          @__root.attribute.find { |attr| attr.name == ref }
        end
      end
    end
  end
end

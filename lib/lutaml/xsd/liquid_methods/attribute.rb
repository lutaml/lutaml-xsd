# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Attribute
        include Lutaml::Model::Liquefiable

        def cardinality
          case use
          when "required" then "1"
          when "optional" then "0..1"
          end
        end

        def used_by_items
        end

        def referenced_object
          return self if ref.start_with?("xml:")

        end
      end
    end
  end
end

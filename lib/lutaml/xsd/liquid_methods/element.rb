# frozen_string_literal: true

module Lutaml
  module Xsd
    module LiquidMethods
      module Element
        include Lutaml::Model::Liquefiable

        def min_occurrences
          @min_occurs&.to_i || 1
        end

        def max_occurrences
          return "*" if @max_occurs == "unbounded"

          @max_occurs&.to_i || 1
        end

        def child_elements(array = [])
          array << self
        end
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class MinInclusive < Base
      attribute :value, :string

      xml do
        root "minInclusive", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
      end

      Lutaml::Xsd.register_model(self, :min_inclusive)
    end
  end
end

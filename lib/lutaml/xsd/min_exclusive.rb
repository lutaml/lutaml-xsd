# frozen_string_literal: true

module Lutaml
  module Xsd
    class MinExclusive < Base
      attribute :fixed, :string
      attribute :value, :integer

      xml do
        root "minExclusive", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
        map_attribute :fixed, to: :fixed
      end

      Lutaml::Xsd.register_model(self, :min_exclusive)
    end
  end
end

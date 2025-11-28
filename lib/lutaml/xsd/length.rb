# frozen_string_literal: true

module Lutaml
  module Xsd
    class Length < Base
      attribute :fixed, :boolean
      attribute :value, :integer
      attribute :annotation, :annotation

      xml do
        root "length", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :fixed, to: :fixed
        map_attribute :value, to: :value
        map_element :annotation, to: :annotation
      end

      Lutaml::Xsd.register_model(self, :length)
    end
  end
end

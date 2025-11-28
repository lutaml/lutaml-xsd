# frozen_string_literal: true

module Lutaml
  module Xsd
    class Enumeration < Base
      attribute :value, :string
      attribute :annotation, :annotation

      xml do
        root "enumeration", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
        map_element :annotation, to: :annotation
      end

      Lutaml::Xsd.register_model(self, :enumeration)
    end
  end
end

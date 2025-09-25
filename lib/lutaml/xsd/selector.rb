# frozen_string_literal: true

module Lutaml
  module Xsd
    class Selector < Base
      attribute :id, :string
      attribute :xpath, :string
      attribute :annotation, :annotation

      xml do
        root "selector", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :xpath, to: :xpath
        map_element :annotation, to: :annotation
      end

      Lutaml::Xsd.register_model(self, :selector)
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Unique < Base
      attribute :id, :string
      attribute :name, :string
      attribute :selector, :selector
      attribute :annotation, :annotation
      attribute :field, :field, collection: true, initialize_empty: true

      xml do
        root "unique", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_element :annotation, to: :annotation
        map_element :selector, to: :selector
        map_element :field, to: :field
      end

      Lutaml::Xsd.register_model(self, :unique)
    end
  end
end

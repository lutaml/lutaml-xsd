# frozen_string_literal: true

module Lutaml
  module Xsd
    class Unique < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :selector, Selector, collection: true
      attribute :field, Field, collection: true

      xml do
        root "unique", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_element :selector, to: :selector
        map_element :field, to: :field
      end
    end
  end
end

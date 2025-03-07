# frozen_string_literal: true

module Lutaml
  module Xsd
    class Unique < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :selector, Selector
      attribute :annotation, Annotation
      attribute :field, Field, collection: true, initialize_empty: true

      xml do
        root "unique", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_element :annotation, to: :annotation
        map_element :selector, to: :selector
        map_element :field, to: :field
      end
    end
  end
end

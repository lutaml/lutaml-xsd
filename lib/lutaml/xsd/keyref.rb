# frozen_string_literal: true

module Lutaml
  module Xsd
    class Keyref < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :refer, :string
      attribute :selector, Selector
      attribute :annotation, Annotation
      attribute :field, Field, collection: true, initialize_empty: true
      # Field should be one or more

      xml do
        root "keyref", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_element :field, to: :field
        map_element :selector, to: :selector
        map_element :annotation, to: :annotation
      end
    end
  end
end

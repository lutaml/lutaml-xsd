# frozen_string_literal: true

module Lutaml
  module Xsd
    class SimpleType < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :union, Union, collection: true
      attribute :annotation, Annotation, collection: true
      attribute :enumeration, Enumeration, collection: true
      attribute :restriction, Restriction, collection: true

      xml do
        root "simpleType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_element :union, to: :union
        map_element :annotation, to: :annotation
        map_element :restriction, to: :restriction
        map_element :enumeration, to: :enumeration
      end
    end
  end
end

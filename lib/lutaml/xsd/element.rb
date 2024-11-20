# frozen_string_literal: true

module Lutaml
  module Xsd
    class Element < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :type, :string
      attribute :default, :string
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :key, Key, collection: true
      attribute :unique, Unique, collection: true
      attribute :complex_type, ComplexType, collection: true
      attribute :simple_type, SimpleType, collection: true
      attribute :annotation, Annotation, collection: true

      xml do
        root "element", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_attribute :default, to: :default
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :complexType, to: :complex_type
        map_element :simpleType, to: :simple_type
        map_element :annotation, to: :annotation
        map_element :unique, to: :unique
        map_element :key, to: :key
      end
    end
  end
end

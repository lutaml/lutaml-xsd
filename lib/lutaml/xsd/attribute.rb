# frozen_string_literal: true

module Lutaml
  module Xsd
    class Attribute < Lutaml::Model::Serializable
      attribute :use, :string
      attribute :name, :string
      attribute :type, :string
      attribute :default, :string
      attribute :annotation, Annotation, collection: true
      attribute :simple_type, SimpleType, collection: true

      xml do
        root "attribute", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :use, to: :use
        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_attribute :default, to: :default
        map_element :annotation, to: :annotation
        map_element :simpleType, to: :simple_type
      end
    end
  end
end

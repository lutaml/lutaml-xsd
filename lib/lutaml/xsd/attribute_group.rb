# frozen_string_literal: true

module Lutaml
  module Xsd
    class AttributeGroup < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :ref, :string
      attribute :annotation, Annotation, collection: true
      attribute :attribute, Attribute, collection: true

      xml do
        root "attributeGroup", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_element :annotation, to: :annotation
        map_element :attribute, to: :attribute
      end
    end
  end
end

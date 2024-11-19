# frozen_string_literal: true

module Lutaml
  module Xsd
    class ComplexType < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :mixed, :string
      attribute :abstract, :string
      attribute :choice, Choice, collection: true
      attribute :sequence, Sequence, collection: true
      attribute :attribute, Attribute, collection: true
      attribute :annotation, Annotation, collection: true
      attribute :attribute_group, AttributeGroup, collection: true
      attribute :simple_content, SimpleContent, collection: true
      attribute :complex_content, ComplexContent, collection: true

      xml do
        root "complexType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_attribute :mixed, to: :mixed
        map_attribute :abstract, to: :abstract
        map_element :choice, to: :choice
        map_element :sequence, to: :sequence
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :attributeGroup, to: :attribute_group
        map_element :simpleContent, to: :simple_content
        map_element :complexContent, to: :complex_content
      end
    end
  end
end

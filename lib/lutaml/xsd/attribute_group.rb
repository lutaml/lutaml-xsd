# frozen_string_literal: true

module Lutaml
  module Xsd
    class AttributeGroup < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :ref, :string
      attribute :annotation, Annotation
      attribute :any_attribute, AnyAttribute
      attribute :attribute, Attribute, collection: true, initialize_empty: true
      attribute :attribute_group, AttributeGroup, collection: true, initialize_empty: true

      xml do
        root "attributeGroup", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :anyAttribute, to: :any_attribute
        map_element :attributeGroup, to: :attribute_group
      end
    end
  end
end

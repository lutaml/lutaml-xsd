# frozen_string_literal: true

module Lutaml
  module Xsd
    class ExtensionSimpleContent < Model::Serializable
      attribute :id, :string
      attribute :base, :string
      attribute :annotation, Annotation
      attribute :any_attribute, AnyAttribute
      attribute :attribute, Attribute, collection: true
      attribute :attribute_group, AttributeGroup, collection: true

      xml do
        root "extension", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :base, to: :base
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :any_attribute, to: :any_attribute
        map_element :attributeGroup, to: :attribute_group
      end
    end
  end
end
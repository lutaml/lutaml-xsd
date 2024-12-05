# frozen_string_literal: true

module Lutaml
  module Xsd
    class Redefine < Model::Serializable
      attribute :id, :string
      attribute :schema_path, :string
      attribute :group, Group
      attribute :annotation, Annotation
      attribute :simple_type, SimpleType
      attribute :complex_type, ComplexType
      attribute :attribute_group, AttributeGroup

      xml do
        root "redefine", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :schema_location, to: :schema_path
        map_element :group, to: :group
        map_element :annotation, to: :annotation
        map_element :simpleType, to: :simpleType
        map_element :complexType, to: :complexType
        map_element :attributeGroup, to: :attributeGroup
      end
    end
  end
end

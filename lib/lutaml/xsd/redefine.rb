# frozen_string_literal: true

module Lutaml
  module Xsd
    class Redefine < Base
      attribute :id, :string
      attribute :schema_path, :string
      attribute :group, :group
      attribute :annotation, :annotation
      attribute :simple_type, :simple_type
      attribute :complex_type, :complex_type
      attribute :attribute_group, :attribute_group

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

      Lutaml::Xsd.register_model(self, :redefine)
    end
  end
end

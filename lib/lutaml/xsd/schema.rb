# frozen_string_literal: true

module Lutaml
  module Xsd
    class Schema < Lutaml::Model::Serializable
      attribute :xmlns, :string
      attribute :import, Import, collection: true
      attribute :include, Include, collection: true
      attribute :element, Element, collection: true
      attribute :complex_type, ComplexType, collection: true
      attribute :simple_type, SimpleType, collection: true
      attribute :group, Group, collection: true
      attribute :attribute_group, AttributeGroup, collection: true
      attribute :element_form_default, :string
      attribute :attribute_form_default, :string
      attribute :block_default, :string
      attribute :target_namespace, :string

      xml do
        root "schema", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :xmlns, to: :xmlns, namespace: "http://csrc.nist.gov/ns/oscal/metaschema/1.0", prefix: nil
        map_element :import, to: :import
        map_element :include, to: :include
        map_element :element, to: :element
        map_element :complexType, to: :complex_type
        map_element :simpleType, to: :simple_type
        map_element :group, to: :group
        map_element :attributeGroup, to: :attribute_group
        map_attribute :elementFormDefault, to: :element_form_default
        map_attribute :attributeFormDefault, to: :attribute_form_default
        map_attribute :blockDefault, to: :block_default
        map_attribute :targetNamespace, to: :target_namespace
      end
    end
  end
end

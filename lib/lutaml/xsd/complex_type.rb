# frozen_string_literal: true

module Lutaml
  module Xsd
    class ComplexType < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :final, :string
      attribute :block, :string
      attribute :mixed, :boolean, default: -> { false }
      attribute :abstract, :boolean, default: -> { false }
      attribute :all, All
      attribute :group, Group
      attribute :choice, Choice
      attribute :sequence, Sequence
      attribute :annotation, Annotation
      attribute :simple_content, SimpleContent
      attribute :complex_content, ComplexContent
      attribute :attribute, Attribute, collection: true, initialize_empty: true
      attribute :attribute_group, AttributeGroup, collection: true, initialize_empty: true

      xml do
        root "complexType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_attribute :final, to: :final
        map_attribute :block, to: :block
        map_attribute :mixed, to: :mixed
        map_attribute :abstract, to: :abstract
        map_element :all, to: :all
        map_element :group, to: :group
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

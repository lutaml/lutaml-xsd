# frozen_string_literal: true

require_relative "liquid_methods/complex_type"

module Lutaml
  module Xsd
    class ComplexType < Base
      include LiquidMethods::ComplexType

      attribute :id, :string
      attribute :name, :string
      attribute :final, :string
      attribute :block, :string
      attribute :mixed, :boolean, default: -> { false }
      attribute :abstract, :boolean, default: -> { false }
      attribute :all, :all
      attribute :group, :group
      attribute :choice, :choice
      attribute :sequence, :sequence
      attribute :annotation, :annotation
      attribute :simple_content, :simple_content
      attribute :complex_content, :complex_content
      attribute :attribute, :attribute, collection: true, initialize_empty: true
      attribute :attribute_group, :attribute_group, collection: true, initialize_empty: true

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

      # liquid do

      #         map "used_by", to: :used_by

      #         map "child_elements", to: :child_elements

      #         map "attribute_elements", to: :attribute_elements

      #       end

      Lutaml::Xsd.register_model(self, :complex_type)
    end
  end
end

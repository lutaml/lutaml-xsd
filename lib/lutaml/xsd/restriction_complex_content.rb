# frozen_string_literal: true

module Lutaml
  module Xsd
    class RestrictionComplexContent < Model::Serializable
      attribute :id, :string
      attribute :base, :string
      attribute :all, :all
      attribute :group, :group
      attribute :choice, :choice
      attribute :sequence, :sequence
      attribute :annotation, :annotation
      attribute :any_attribute, :any_attribute
      attribute :attribute, :attribute, collection: true, initialize_empty: true
      attribute :attribute_group, :attribute_group, collection: true, initialize_empty: true

      xml do
        root "restriction", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :base, to: :base
        map_element :all, to: :all
        map_element :group, to: :group
        map_element :choice, to: :choice
        map_element :sequence, to: :sequence
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :anyAttribute, to: :any_attribute
        map_element :attributeGroup, to: :attribute_group
      end

      Lutaml::Xsd.register_model(self, :restriction_complex_content)
    end
  end
end

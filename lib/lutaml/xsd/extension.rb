# frozen_string_literal: true

module Lutaml
  module Xsd
    class Extension < Lutaml::Model::Serializable
      attribute :base, :string
      attribute :sequence, Sequence, collection: true
      attribute :attribute, Attribute, collection: true
      attribute :annotation, Annotation, collection: true
      attribute :attribute_group, AttributeGroup, collection: true

      xml do
        root "extension", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :base, to: :base
        map_element :sequence, to: :sequence
        map_element :attribute, to: :attribute
        map_element :annotation, to: :annotation
        map_element :attributeGroup, to: :attribute_group
      end
    end
  end
end

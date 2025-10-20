# frozen_string_literal: true

module Lutaml
  module Xsd
    class ExtensionSimpleContent < Base
      attribute :id, :string
      attribute :base, :string
      attribute :annotation, :annotation
      attribute :any_attribute, :any_attribute
      attribute :attribute, :attribute, collection: true, initialize_empty: true
      attribute :attribute_group, :attribute_group, collection: true, initialize_empty: true

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

      Lutaml::Xsd.register_model(self, :extension_simple_content)
    end
  end
end

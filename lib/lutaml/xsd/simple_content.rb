# frozen_string_literal: true

require_relative "liquid_methods/simple_content"

module Lutaml
  module Xsd
    class SimpleContent < Base
      include LiquidMethods::SimpleContent

      attribute :id, :string
      attribute :base, :string
      attribute :annotation, :annotation
      attribute :extension, :extension_simple_content
      attribute :restriction, :restriction_simple_content

      xml do
        root "simpleContent", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :base, to: :base
        map_element :restriction, to: :restriction
        map_element :annotation, to: :annotation
        map_element :extension, to: :extension
      end

      liquid do
        map "base_type", to: :base_type
        map "attribute_elements", to: :attribute_elements
      end

      Lutaml::Xsd.register_model(self, :simple_content)
    end
  end
end

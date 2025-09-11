# frozen_string_literal: true

module Lutaml
  module Xsd
    class SimpleContent < Model::Serializable
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

      Lutaml::Xsd.register_model(self, :simple_content)
    end
  end
end

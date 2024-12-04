# frozen_string_literal: true

module Lutaml
  module Xsd
    class ExtensionComplexContent < Model::Serializable; end

    class ComplexContent < Model::Serializable
      attribute :id, :string
      attribute :mixed, :boolean
      attribute :extension, ExtensionComplexContent
      attribute :annotation, Annotation
      attribute :restriction, RestrictionComplexContent

      xml do
        root "complexContent", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :mixed, to: :mixed
        map_element :extension, to: :extension
        map_element :annotation, to: :annotation
        map_element :restriction, to: :restriction
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class ComplexContent < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :mixed, :boolean
      attribute :extension, Extension, collection: true
      attribute :restriction, Restriction, collection: true

      xml do
        root "complexContent", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :mixed, to: :mixed
        map_element :extension, to: :extension
        map_element :restriction, to: :restriction
      end
    end
  end
end

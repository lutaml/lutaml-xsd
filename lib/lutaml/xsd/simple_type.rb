# frozen_string_literal: true

module Lutaml
  module Xsd
    class SimpleType < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :final, :string
      attribute :list, List
      attribute :union, Union
      attribute :annotation, Annotation
      attribute :restriction, RestrictionSimpleType

      xml do
        root "simpleType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_attribute :final, to: :final
        map_element :list, to: :list
        map_element :union, to: :union
        map_element :annotation, to: :annotation
        map_element :restriction, to: :restriction
      end
    end
  end
end

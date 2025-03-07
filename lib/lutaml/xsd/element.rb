# frozen_string_literal: true

module Lutaml
  module Xsd
    class Element < Model::Serializable
      attribute :id, :string
      attribute :ref, :string
      attribute :name, :string
      attribute :type, :string
      attribute :form, :string
      attribute :block, :string
      attribute :final, :string
      attribute :fixed, :string
      attribute :default, :string
      attribute :nillable, :string
      attribute :abstract, :boolean, default: -> { false }
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :substitution_group, :string
      attribute :annotation, Annotation
      attribute :simple_type, SimpleType
      attribute :complex_type, ComplexType
      attribute :key, Key, collection: true, initialize_empty: true
      attribute :keyref, Keyref, collection: true, initialize_empty: true
      attribute :unique, Unique, collection: true, initialize_empty: true

      xml do
        root "element", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_attribute :form, to: :form
        map_attribute :block, to: :block
        map_attribute :final, to: :final
        map_attribute :fixed, to: :fixed
        map_attribute :default, to: :default
        map_attribute :nillable, to: :nillable
        map_attribute :abstract, to: :abstract
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_attribute :substitutionGroup, to: :substitution_group
        map_element :complexType, to: :complex_type
        map_element :simpleType, to: :simple_type
        map_element :annotation, to: :annotation
        map_element :keyref, to: :keyref
        map_element :unique, to: :unique
        map_element :key, to: :key
      end
    end
  end
end

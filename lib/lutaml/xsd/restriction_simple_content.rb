# frozen_string_literal: true

module Lutaml
  module Xsd
    class RestrictionSimpleContent < Model::Serializable
      attribute :id, :string
      attribute :base, :string
      attribute :annotation, Annotation
      attribute :simple_type, SimpleType
      attribute :any_attribute, AnyAttribute
      attribute :length, Length, collection: true, initialize_empty: true
      attribute :pattern, Pattern, collection: true, initialize_empty: true
      attribute :attribute, Attribute, collection: true, initialize_empty: true
      attribute :max_length, MaxLength, collection: true, initialize_empty: true
      attribute :min_length, MinLength, collection: true, initialize_empty: true
      attribute :white_space, WhiteSpace, collection: true, initialize_empty: true
      attribute :enumeration, Enumeration, collection: true, initialize_empty: true
      attribute :total_digits, TotalDigits, collection: true, initialize_empty: true
      attribute :min_exclusive, MinExclusive, collection: true, initialize_empty: true
      attribute :min_inclusive, MinInclusive, collection: true, initialize_empty: true
      attribute :max_exclusive, MaxExclusive, collection: true, initialize_empty: true
      attribute :max_inclusive, MaxInclusive, collection: true, initialize_empty: true
      attribute :attribute_group, AttributeGroup, collection: true, initialize_empty: true
      attribute :fraction_digits, FractionDigits, collection: true, initialize_empty: true

      xml do
        root "restriction", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :base, to: :base
        map_element :fractionDigits, to: :fraction_digits
        map_element :attributeGroup, to: :attribute_group
        map_element :minInclusive, to: :min_inclusive
        map_element :maxInclusive, to: :max_inclusive
        map_element :anyAttribute, to: :any_attribute
        map_element :minExclusive, to: :min_exclusive
        map_element :maxExclusive, to: :max_exclusive
        map_element :totalDigits, to: :total_digits
        map_element :enumeration, to: :enumeration
        map_element :simpleType, to: :simple_type
        map_element :whiteSpace, to: :white_space
        map_element :annotation, to: :annotation
        map_element :maxLength, to: :max_length
        map_element :minLength, to: :min_length
        map_element :attribute, to: :attribute
        map_element :pattern, to: :pattern
        map_element :length, to: :length
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class RestrictionSimpleType < Model::Serializable
      attribute :id, :string
      attribute :base, :string
      attribute :annotation, Annotation
      attribute :simple_type, SimpleType
      attribute :length, Length, collection: true
      attribute :pattern, Pattern, collection: true
      attribute :min_length, MinLength, collection: true
      attribute :max_length, MaxLength, collection: true
      attribute :white_space, WhiteSpace, collection: true
      attribute :enumeration, Enumeration, collection: true
      attribute :total_digits, TotalDigits, collection: true
      attribute :max_exclusive, MaxExclusive, collection: true
      attribute :min_exclusive, MinExclusive, collection: true
      attribute :max_inclusive, MaxInclusive, collection: true
      attribute :min_inclusive, MinInclusive, collection: true
      attribute :fraction_digits, FractionDigits, collection: true

      xml do
        root "restriction", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :base, to: :base
        map_element :length, to: :length
        map_element :pattern, to: :pattern
        map_element :minLength, to: :min_length
        map_element :maxLength, to: :max_length
        map_element :annotation, to: :annotation
        map_element :whiteSpace, to: :white_space
        map_element :simple_type, to: :simple_type
        map_element :enumeration, to: :enumeration
        map_element :totalDigits, to: :total_digits
        map_element :maxExclusive, to: :max_exclusive
        map_element :minExclusive, to: :min_exclusive
        map_element :maxInclusive, to: :max_inclusive
        map_element :minInclusive, to: :min_inclusive
        map_element :fractionDigits, to: :fraction_digits
      end
    end
  end
end

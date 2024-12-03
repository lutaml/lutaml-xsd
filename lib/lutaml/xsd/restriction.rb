# frozen_string_literal: true

module Lutaml
  module Xsd
    class Restriction < Lutaml::Model::Serializable
      attribute :base, :string
      attribute :length, Length
      attribute :pattern, Pattern
      attribute :max_length, MaxLength
      attribute :min_inclusive, MinInclusive
      attribute :max_inclusive, MaxInclusive
      attribute :annotation, Annotation, collection: true
      attribute :white_space, WhiteSpace, collection: true
      attribute :enumeration, Enumeration, collection: true

      xml do
        root "restriction", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :base, to: :base
        map_element :minInclusive, to: :min_inclusive
        map_element :maxInclusive, to: :max_inclusive
        map_element :enumeration, to: :enumeration
        map_element :whiteSpace, to: :white_space
        map_element :annotation, to: :annotation
        map_element :maxLength, to: :max_length
        map_element :pattern, to: :pattern
        map_element :length, to: :length
      end
    end
  end
end

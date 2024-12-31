# frozen_string_literal: true

module Lutaml
  module Xsd
    class FractionDigits < Model::Serializable
      attribute :id, :string
      attribute :value, :string
      attribute :fixed, :string
      attribute :annotation, Annotation

      xml do
        root "fractionDigits", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :value, to: :value
        map_attribute :fixed, to: :fixed
        map_element :annotation, to: :annotation
      end
    end
  end
end

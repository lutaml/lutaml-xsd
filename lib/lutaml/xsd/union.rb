# frozen_string_literal: true

module Lutaml
  module Xsd
    class Union < Model::Serializable
      attribute :id, :string
      attribute :member_types, :string, default: -> { "" }
      attribute :annotation, Annotation
      attribute :simple_type, SimpleType, collection: true, initialize_empty: true

      xml do
        root "union", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :memberTypes, to: :member_types
        map_element :annotation, to: :annotation
        map_element :simpleType, to: :simple_type
      end
    end
  end
end

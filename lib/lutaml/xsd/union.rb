# frozen_string_literal: true

module Lutaml
  module Xsd
    class Union < Lutaml::Model::Serializable
      attribute :member_types, :string
      attribute :simple_type, SimpleType, collection: true

      xml do
        root "union", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :memberTypes, to: :member_types
        map_element :simpleType, to: :simple_type
      end
    end
  end
end

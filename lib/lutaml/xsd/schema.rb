# frozen_string_literal: true

module Lutaml
  module Xsd
    class Schema < Lutaml::Model::Serializable
      attribute :import, Import
      attribute :element, Element
      attribute :complex_type, ComplexType
      attribute :simple_type, SimpleType
      attribute :group, Group

      xml do
        root "schema", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :import, to: :import, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :element, to: :element, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :complexType, to: :complex_type, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :simpleType, to: :simple_type, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :group, to: :group, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

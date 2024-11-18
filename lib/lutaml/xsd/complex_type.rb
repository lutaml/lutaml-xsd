# frozen_string_literal: true

module Lutaml
  module Xsd
    class ComplexType < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :attribute, Attribute
      attribute :sequence, Sequence
      attribute :simple_content, SimpleContent

      xml do
        root "complexType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_element :attribute, to: :attribute, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :sequence, to: :sequence, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :simpleContent, to: :simple_content, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

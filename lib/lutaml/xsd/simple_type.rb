# frozen_string_literal: true

module Lutaml
  module Xsd
    class SimpleType < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :annotation, Annotation
      attribute :restriction, Restriction

      xml do
        root "simpleType", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_element :annotation, to: :annotation, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :restriction, to: :restriction, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Element < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :type, :string
      attribute :annotation, Annotation
      attribute :unique, Unique

      xml do
        root "element", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_element :annotation, to: :annotation, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :unique, to: :unique, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

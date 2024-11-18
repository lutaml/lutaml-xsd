# frozen_string_literal: true

module Lutaml
  module Xsd
    class Attribute < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :type, :string
      attribute :use, :string
      attribute :annotation, Annotation

      xml do
        root "attribute", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_attribute :use, to: :use
        map_element :annotation, to: :annotation, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

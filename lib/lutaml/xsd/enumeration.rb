# frozen_string_literal: true

module Lutaml
  module Xsd
    class Enumeration < Lutaml::Model::Serializable
      attribute :value, :string
      attribute :annotation, Annotation

      xml do
        root "enumeration", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
        map_element :annotation, to: :annotation, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

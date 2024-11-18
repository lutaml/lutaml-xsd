# frozen_string_literal: true

module Lutaml
  module Xsd
    class Extension < Lutaml::Model::Serializable
      attribute :base, :string
      attribute :attribute, Attribute

      xml do
        root "extension", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :base, to: :base
        map_element :attribute, to: :attribute, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

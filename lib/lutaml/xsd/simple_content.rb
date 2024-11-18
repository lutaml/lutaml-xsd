# frozen_string_literal: true

module Lutaml
  module Xsd
    class SimpleContent < Lutaml::Model::Serializable
      attribute :base, :string
      attribute :extension, Extension

      xml do
        root "simpleContent", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :base, to: :base
        map_element :extension, to: :extension, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

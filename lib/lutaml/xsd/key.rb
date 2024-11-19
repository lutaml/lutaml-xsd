# frozen_string_literal: true

module Lutaml
  module Xsd
    class Key < Lutaml::Model::Serializable
      attribute :name, :string
      attribute :selector, Selector
      attribute :field, Field

      xml do
        root "key", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :name, to: :name
        map_element :selector, to: :selector
        map_element :field, to: :field
      end
    end
  end
end

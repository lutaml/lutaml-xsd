# frozen_string_literal: true

require_relative "liquid_methods/attribute"

module Lutaml
  module Xsd
    class Attribute < Base
      include LiquidMethods::Attribute

      attribute :id, :string
      attribute :use, :string, values: %w[required prohibited optional], default: -> { "optional" }
      attribute :ref, :string
      attribute :name, :string
      attribute :type, :string
      attribute :form, :string
      attribute :fixed, :string
      attribute :default, :string
      attribute :annotation, :annotation
      attribute :simple_type, :simple_type

      xml do
        root "attribute", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :use, to: :use
        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_attribute :type, to: :type
        map_attribute :form, to: :form
        map_attribute :fixed, to: :fixed
        map_attribute :default, to: :default
        map_element :annotation, to: :annotation
        map_element :simpleType, to: :simple_type
      end

      # liquid do

      #         map "cardinality", to: :cardinality

      #         map "referenced_name", to: :referenced_name

      #         map "referenced_type", to: :referenced_type

      #         map "referenced_object", to: :referenced_object

      #       end

      Lutaml::Xsd.register_model(self, :attribute)
    end
  end
end

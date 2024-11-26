# frozen_string_literal: true

module Lutaml
  module Xsd
    class Include < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :schema_location, :string
      attribute :annotation, Annotation

      xml do
        root "include", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_element :annotation, to: :annotation
      end

      def include_schema
        Glob.include_schema(schema_location)
      end
    end
  end
end

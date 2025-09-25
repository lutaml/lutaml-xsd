# frozen_string_literal: true

module Lutaml
  module Xsd
    class Include < Base
      attribute :id, :string
      attribute :schema_path, :string
      attribute :annotation, :annotation

      xml do
        root "include", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :schemaLocation, to: :schema_path
        map_element :annotation, to: :annotation
      end

      def fetch_schema
        Glob.include_schema(schema_path)
      end

      Lutaml::Xsd.register_model(self, :include)
    end
  end
end

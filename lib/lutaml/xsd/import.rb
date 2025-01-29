# frozen_string_literal: true

module Lutaml
  module Xsd
    class Import < Model::Serializable
      attribute :id, :string
      attribute :namespace, :string
      attribute :schema_path, :string
      attribute :annotation, Annotation

      xml do
        root "import", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :namespace, to: :namespace
        map_attribute :schemaLocation, to: :schema_path
        map_element :annotation, to: :annotation
      end

      def fetch_schema
        Glob.include_schema(schema_path) if schema_path && Glob.location?
      end
    end
  end
end

# frozen_string_literal: true

require "net/http"
module Lutaml
  module Xsd
    class Import < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :namespace, :string
      attribute :schema_location, :string

      xml do
        root "import", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :namespace, to: :namespace
      end

      def import_schema
        if Glob.location? && schema_location
          if Glob.url?
            Net::HTTP.get(
              URI.parse(
                Glob.schema_location_path(schema_location),
              ),
            )
          else
            File.read(
              Glob.schema_location_path(schema_location),
            )
          end
        end
      end
    end
  end
end

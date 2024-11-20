# frozen_string_literal: true

module Lutaml
  module Xsd
    class Import < Lutaml::Model::Serializable
      attribute :id, :string
      attribute :namespace, :string

      xml do
        root "import", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :namespace, to: :namespace
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Any < Lutaml::Model::Serializable
      attribute :namespace, :string
      attribute :process_contents, :string

      xml do
        root "any", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :namespace, to: :namespace
        map_attribute :processContents, to: :process_contents
      end
    end
  end
end

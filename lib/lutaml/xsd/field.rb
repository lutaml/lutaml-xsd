# frozen_string_literal: true

module Lutaml
  module Xsd
    class Field < Lutaml::Model::Serializable
      attribute :xpath, :string

      xml do
        root "field", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :xpath, to: :xpath
      end
    end
  end
end

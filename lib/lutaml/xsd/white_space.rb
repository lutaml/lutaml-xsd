# frozen_string_literal: true

module Lutaml
  module Xsd
    class WhiteSpace < Lutaml::Model::Serializable
      attribute :value, :string

      xml do
        root "whiteSpace", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
      end
    end
  end
end

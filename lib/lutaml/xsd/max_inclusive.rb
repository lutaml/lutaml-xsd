# frozen_string_literal: true

module Lutaml
  module Xsd
    class MaxInclusive < Model::Serializable
      attribute :value, :string

      xml do
        root "maxInclusive", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
      end
    end
  end
end

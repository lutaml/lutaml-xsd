# frozen_string_literal: true

module Lutaml
  module Xsd
    class MaxExclusive < Model::Serializable
      attribute :fixed, :string
      attribute :value, :integer

      xml do
        root "maxExclusive", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
        map_attribute :fixed, to: :fixed
      end
    end
  end
end

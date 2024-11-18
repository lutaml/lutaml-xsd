# frozen_string_literal: true

module Lutaml
  module Xsd
    class Restriction < Lutaml::Model::Serializable
      attribute :base, :string
      attribute :min_inclusive, MinInclusive
      attribute :max_inclusive, MaxInclusive
      attribute :enumeration, Enumeration

      xml do
        root "restriction", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :base, to: :base
        map_element :minInclusive, to: :min_inclusive, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :maxInclusive, to: :max_inclusive, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :enumeration, to: :enumeration, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

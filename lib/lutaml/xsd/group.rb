# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Lutaml::Model::Serializable; end
    class Choice < Lutaml::Model::Serializable; end

    class Group < Lutaml::Model::Serializable
      attribute :ref, :string
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :sequence, Sequence
      attribute :choice, Choice

      xml do
        root "group", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :ref, to: :ref
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :sequence, to: :sequence, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :choice, to: :choice, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

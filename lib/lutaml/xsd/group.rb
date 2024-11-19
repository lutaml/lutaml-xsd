# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Lutaml::Model::Serializable; end
    class Choice < Lutaml::Model::Serializable; end

    class Group < Lutaml::Model::Serializable
      attribute :ref, :string
      attribute :name, :string
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :choice, Choice, collection: true
      attribute :sequence, Sequence, collection: true
      attribute :annotation, Annotation, collection: true

      xml do
        root "group", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :annotation, to: :annotation
        map_element :sequence, to: :sequence
        map_element :choice, to: :choice
      end
    end
  end
end

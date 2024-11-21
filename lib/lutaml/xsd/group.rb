# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Model::Serializable; end
    class Choice < Model::Serializable; end

    class Group < Model::Serializable
      attribute :id, :string
      attribute :ref, :string
      attribute :name, :string
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :all, All
      attribute :choice, Choice
      attribute :sequence, Sequence
      attribute :annotation, Annotation

      xml do
        root "group", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :ref, to: :ref
        map_attribute :name, to: :name
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :annotation, to: :annotation
        map_element :sequence, to: :sequence
        map_element :choice, to: :choice
        map_element :all, to: :all
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Choice < Model::Serializable; end

    class Sequence < Model::Serializable
      attribute :id, :string
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :annotation, Annotation
      attribute :sequence, Sequence, collection: true
      attribute :element, Element, collection: true
      attribute :choice, Choice, collection: true
      attribute :group, Group, collection: true
      attribute :any, Any, collection: true

      xml do
        root "sequence", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :annotation, to: :annotation
        map_element :sequence, to: :sequence
        map_element :element, to: :element
        map_element :choice, to: :choice
        map_element :group, to: :group
        map_element :any, to: :any
      end
    end
  end
end

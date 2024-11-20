# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Lutaml::Model::Serializable; end

    class Choice < Lutaml::Model::Serializable
      attribute :any, Any, collection: true
      attribute :min_occurs, :string
      attribute :max_occurs, :string
      attribute :element, Element, collection: true
      attribute :sequence, Sequence, collection: true
      attribute :group, Group, collection: true

      xml do
        root "choice", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :minOccurs, to: :min_occurs
        map_attribute :maxOccurs, to: :max_occurs
        map_element :element, to: :element
        map_element :sequence, to: :sequence
        map_element :group, to: :group
        map_element :any, to: :any
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class All < Model::Serializable
      attribute :id, :string
      attribute :max_occurs, :string
      attribute :min_occurs, :string
      attribute :annotation, Annotation
      attribute :element, Element, collection: true, initialize_empty: true

      xml do
        root "all", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :max_occurs, to: :max_occurs
        map_attribute :min_occurs, to: :min_occurs
        map_element :annotation, to: :annotation
        map_element :element, to: :element
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Choice < Lutaml::Model::Serializable; end

    class Sequence < Lutaml::Model::Serializable
      attribute :element, Element, collection: true
      attribute :choice, Choice, collection: true
      attribute :group, Group, collection: true

      xml do
        root "sequence", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :element, to: :element
        map_element :choice, to: :choice
        map_element :group, to: :group
      end
    end
  end
end

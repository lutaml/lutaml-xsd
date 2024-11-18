# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Lutaml::Model::Serializable
      attribute :element, Element
      attribute :choice, Choice
      attribute :group, Group

      xml do
        root "sequence", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :element, to: :element, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :choice, to: :choice, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :group, to: :group, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

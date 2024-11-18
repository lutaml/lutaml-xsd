# frozen_string_literal: true

module Lutaml
  module Xsd
    class Sequence < Lutaml::Model::Serializable; end

    class Choice < Lutaml::Model::Serializable
      attribute :element, Element
      attribute :sequence, Sequence

      xml do
        root "choice", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :element, to: :element, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
        map_element :sequence, to: :sequence, namespace: "http://www.w3.org/2001/XMLSchema", prefix: "xsd"
      end
    end
  end
end

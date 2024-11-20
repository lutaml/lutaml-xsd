# frozen_string_literal: true

module Lutaml
  module Xsd
    class Include < Lutaml::Model::Serializable
      attribute :annotation, Annotation, collection: true

      xml do
        root "include", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :annotation, to: :annotation
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Annotation < Lutaml::Model::Serializable
      attribute :documentation, Documentation, collection: true

      xml do
        root "annotation", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :documentation, to: :documentation
      end
    end
  end
end

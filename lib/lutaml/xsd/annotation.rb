# frozen_string_literal: true

module Lutaml
  module Xsd
    class Annotation < Model::Serializable
      attribute :id, :string
      attribute :documentation, Documentation, collection: true, initialize_empty: true
      attribute :appinfo, Appinfo, collection: true, initialize_empty: true

      xml do
        root "annotation", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_element :documentation, to: :documentation
        map_element :appinfo, to: :appinfo
      end
    end
  end
end

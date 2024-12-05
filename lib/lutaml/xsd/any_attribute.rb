# frozen_string_literal: true

module Lutaml
  module Xsd
    class AnyAttribute < Model::Serializable
      attribute :id, :string
      attribute :namespace, :string
      attribute :process_contents, :string
      attribute :annotation, Annotation

      xml do
        root "anyAttribute", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :namespace, to: :namespace
        map_attribute :processContents, to: :process_contents
        map_element :annotation, to: :annotation
      end
    end
  end
end

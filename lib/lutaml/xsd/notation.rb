# frozen_string_literal: true

module Lutaml
  module Xsd
    class Notation < Model::Serializable
      attribute :id, :string
      attribute :name, :string
      attribute :public, :string
      attribute :system, :string
      attribute :annotation, Annotation

      xml do
        root "notation", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :id, to: :id
        map_attribute :name, to: :name
        map_attribute :public, to: :public
        map_attribute :system, to: :system
        map_element :annotation, to: :annotation
      end
    end
  end
end

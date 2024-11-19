# frozen_string_literal: true

module Lutaml
  module Xsd
    class ComplexContent < Lutaml::Model::Serializable
      attribute :extension, Extension, collection: true

      xml do
        root "complexContent", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_element :extension, to: :extension
      end
    end
  end
end

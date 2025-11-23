# frozen_string_literal: true

module Lutaml
  module Xsd
    class List < Base
      attribute :id, :string
      attribute :item_type, :string
      attribute :annotation, :annotation
      attribute :simple_type, :simple_type

      xml do
        root 'list', mixed: true
        namespace 'http://www.w3.org/2001/XMLSchema', 'xsd'

        map_attribute :id, to: :id
        map_attribute :itemType, to: :item_type
        map_element :annotation, to: :annotation
      end

      Lutaml::Xsd.register_model(self, :list)
    end
  end
end

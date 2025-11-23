# frozen_string_literal: true

module Lutaml
  module Xsd
    class Field < Base
      attribute :id, :string
      attribute :xpath, :string

      xml do
        root 'field', mixed: true
        namespace 'http://www.w3.org/2001/XMLSchema', 'xsd'

        map_attribute :id, to: :id
        map_attribute :xpath, to: :xpath
      end

      Lutaml::Xsd.register_model(self, :field)
    end
  end
end

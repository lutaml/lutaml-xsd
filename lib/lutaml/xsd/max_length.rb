# frozen_string_literal: true

module Lutaml
  module Xsd
    class MaxLength < Lutaml::Model::Serializable
      attribute :value, :integer

      xml do
        root "maxLength", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
      end
    end
  end
end

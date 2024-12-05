# frozen_string_literal: true

module Lutaml
  module Xsd
    class MinLength < Model::Serializable
      attribute :fixed, :string
      attribute :value, :integer

      xml do
        root "minLength", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_attribute :value, to: :value
        map_attribute :fixed, to: :fixed
      end
    end
  end
end

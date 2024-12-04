# frozen_string_literal: true

module Lutaml
  module Xsd
    class Appinfo < Model::Serializable
      attribute :source, :string
      attribute :text, :string

      xml do
        root "appinfo", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_content to: :text
        map_attribute :source, to: :source
      end
    end
  end
end

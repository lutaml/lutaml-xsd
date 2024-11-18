# frozen_string_literal: true

module Lutaml
  module Xsd
    class Documentation < Lutaml::Model::Serializable
      attribute :text, :string

      xml do
        root "documentation", mixed: true
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_content to: :text
      end
    end
  end
end

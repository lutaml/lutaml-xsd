# frozen_string_literal: true

module Lutaml
  module Xsd
    class Documentation < Lutaml::Model::Serializable
      attribute :content, :string

      xml do
        root "documentation"
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_all to: :content
      end
    end
  end
end

# frozen_string_literal: true

module Lutaml
  module Xsd
    class Documentation < Model::Serializable
      attribute :lang, :string
      attribute :source, :string
      attribute :content, :string

      xml do
        root "documentation"
        namespace "http://www.w3.org/2001/XMLSchema", "xsd"

        map_all to: :content
        map_attribute :lang, to: :lang
        map_attribute :source, to: :source
      end

      Lutaml::Xsd.register_model(self, :documentation)
    end
  end
end

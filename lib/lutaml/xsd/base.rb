# frozen_string_literal: true

require "canon"

module Lutaml
  module Xsd
    class Base < Model::Serializable
      XML_REGEX = %r{\<\?xml[^>]+\>\s+}.freeze

      def to_formatted_xml
        Canon.format_xml(to_xml).gsub(XML_REGEX, '')
      end

      # TODO: Update all occurrences of `register_drop_method` to liquid block
      liquid do
        map "to_formatted_xml", to: :to_formatted_xml
      end
    end
  end
end

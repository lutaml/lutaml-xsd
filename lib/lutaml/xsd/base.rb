# frozen_string_literal: true

require "canon"

module Lutaml
  module Xsd
    class Base < Model::Serializable
      XML_REGEX = /<\?xml[^>]+>\s+/

      def to_formatted_xml(except: [])
        Canon.format_xml(
          to_xml(except: except),
        ).gsub(XML_REGEX, "")
      end

      liquid do
        map "to_xml", to: :to_xml
        map "to_formatted_xml", to: :to_formatted_xml
      end
    end
  end
end

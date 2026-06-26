# frozen_string_literal: true

module Lutaml
  module Xsd
    module Stats
      # Extracts a human-readable documentation string from an XSD element's
      # annotation. Single-purpose: element → docstring. Returns "" when the
      # element has no annotation/documentation.
      class DocumentationExtractor
        def self.call(element)
          return "" unless element.annotation&.documentation

          docs = element.annotation.documentation
          docs = [docs] unless docs.is_a?(Array)

          docs.filter_map do |doc|
            content = doc.content || doc.to_s
            content&.strip
          end.first || ""
        end
      end
    end
  end
end

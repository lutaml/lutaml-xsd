# frozen_string_literal: true

module Lutaml
  module Xsd
    class Error < StandardError; end

    module_function

    def parse(xsd, location: nil, nested_schema: false)
      Schema.reset_processed_schemas unless nested_schema

      Glob.path_or_url(location)
      Schema.from_xml(xsd)
    end
  end
end

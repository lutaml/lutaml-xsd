# frozen_string_literal: true

module Lutaml
  module Xsd
    class Error < StandardError; end

    module_function

    def parse(xsd, location: nil)
      Config.set_path_or_url(location)
      Schema.from_xml(xsd)
    end
  end
end
